
--See if the auto update statistic async job is enabled
SELECT 
	is_auto_update_stats_async_on
	,[name]
	,* 
FROM sys.databases
--WHERE name = ''


--see if there are any auto update statistic asy jobs running
SELECT *
FROM sys.dm_exec_background_job_queue

