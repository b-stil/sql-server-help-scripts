
DECLARE @DatabaseName VARCHAR(50) = '';
DECLARE @TriggerName VARCHAR(50) = '';

;WITH base AS (
	SELECT
		OBJECT_NAME(t.parent_id) AS table_name
		,t.[name] AS trigger_name
		,t.is_disabled
		,st.execution_count
		,st.total_worker_time
		,st.cached_time
		,ROW_NUMBER() OVER(PARTITION BY st.object_id ORDER BY st.cached_time DESC) AS rn
		FROM sys.dm_exec_trigger_stats st
		INNER JOIN sys.triggers t ON t.object_id = st.object_id
		WHERE database_id = DB_ID(@DatabaseName)
			AND t.parent_class <> 0
			--AND t.[name] = @TriggerName --Uncomment if you want to query by a specific trigger
)
SELECT
	table_name
	,trigger_name
	,is_disabled
	,execution_count
	,((execution_count*1.0)/DATEDIFF(s, cached_time, GETDATE())) AS calls_per_second
	,((total_worker_time/(execution_count*1.0))/1000000) AS avg_worker_time_seconds_per_exec
FROM base b
WHERE rn = 1;
