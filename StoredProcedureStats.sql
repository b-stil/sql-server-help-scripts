
DECLARE @DatabaseName VARCHAR(100) = '';
DECLARE @ProcName VARCHAR(100) = '';

;WITH base AS (
	SELECT 
		p.[name] as proc_name
		,st.execution_count
		,st.total_worker_time
		,st.cached_time
		,ROW_NUMBER() OVER(PARTITION BY st.object_id ORDER BY st.cached_time DESC) AS rn
	FROM sys.dm_exec_procedure_stats st
	INNER JOIN sys.procedures p ON p.object_id = st.object_id
	WHERE database_id = DB_ID(@DatabaseName)
		--AND p.[name] = @ProcName --Uncomment if you want to run for a specific procedure
)
SELECT
	proc_name
	,execution_count
	,((execution_count*1.0)/DATEDIFF(s, cached_time, GETDATE())) AS calls_per_second
	,((total_worker_time/(execution_count*1.0))/1000000) AS avg_worker_time_seconds_per_exec
FROM base b
WHERE rn = 1;
