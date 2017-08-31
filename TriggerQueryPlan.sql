
DECLARE @TriggerName VARCHAR(100) = '';

SELECT 
	t.name
	,s.cached_time AS Cached
	,DATEDIFF(mi, s.cached_time, SYSUTCDATETIME()) AS MinutesSinceCached
	,s.last_execution_time
	,s.execution_count
	,(s.execution_count / (DATEDIFF(mi, s.cached_time, SYSUTCDATETIME()))) AS CountPerMinute
	,query_plan
FROM sys.dm_exec_trigger_stats s
INNER JOIN sys.triggers t ON t.object_id = s.object_id
inner join sys.dm_exec_cached_plans p on p.plan_handle = s.plan_handle
CROSS APPLY sys.dm_exec_query_plan(s.plan_handle)
WHERE t.name LIKE '%' + @TriggerName + '%';