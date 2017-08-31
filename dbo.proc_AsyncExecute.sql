
CREATE PROCEDURE proc_AsyncExecute(
	@SqlCommand varchar(4000)
	,@JobName varchar(200) = NULL
	,@Database varchar(200)= NULL
	,@Owner varchar(200) = null )
AS BEGIN
	SET NOCOUNT ON;

	DECLARE @id UNIQUEIDENTIFIER;
	
	--Create unique job name if the name is not specified
	IF (@JobName IS NULL)
	BEGIN
		SET @JobName= 'async_temp';
	END
	ELSE
	BEGIN
		SET @JobName = @JobName + '_' + CONVERT(VARCHAR(64),NEWID())
	END
	
	IF (@Owner IS NULL)
	BEGIN
		SET @Owner = 'sa';
	END

	--Create a new job, get job ID
	EXECUTE msdb..sp_add_job @JobName, @owner_login_name=@Owner, @job_id=@id OUTPUT

	--Specify a job server for the job
	EXECUTE msdb..sp_add_jobserver @job_id=@id

	--Specify a first step of the job - the SQL command
	--(@on_success_action = 3 ... Go to next step)
	EXECUTE msdb..sp_add_jobstep @job_id=@id, @step_name='Step1', @command = @SqlCommand, 
		@database_name = @database, @on_success_action = 3 

	--Specify next step of the job - delete the job
	DECLARE @deletecommand varchar(200)
	SET @deletecommand = 'execute msdb..sp_delete_job @job_name='''+@JobName+''''
	EXECUTE msdb..sp_add_jobstep @job_id=@id, @step_name='Step2', @command = @deletecommand

	--Start the job
	EXECUTE msdb..sp_start_job @job_id=@id

END
GO