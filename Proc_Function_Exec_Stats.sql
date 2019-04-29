/**** Note that the DM views that are being queried won't have a row for an object that hasn't been used *****/
/**** Run this script in the context of the database that the results are needed for ****/

;WITH base AS (
	SELECT 
		pt.object_id
		,'Procedure' AS ObjectType
		,pt.execution_count AS ExecCount
		,pt.total_worker_time
		,pt.cached_time
		,ROW_NUMBER() OVER(PARTITION BY pt.[object_id] ORDER BY pt.cached_time DESC) AS rn
	FROM sys.dm_exec_procedure_stats pt
	UNION ALL
	SELECT 
		ft.object_id
		,'Function' AS ObjectType
		,ft.execution_count AS ExecCount
		,ft.total_worker_time
		,ft.cached_time
		,ROW_NUMBER() OVER(PARTITION BY ft.[object_id] ORDER BY ft.cached_time DESC) AS rn
	FROM sys.dm_exec_function_stats ft
)
SELECT 
	DB_NAME() AS DatabaseName  /*From current DB context*/
	,s.[name] AS SchemaName
	,o.[name] AS ObjectName
	,b.ObjectType
	,b.ExecCount
	,((b.ExecCount*1.0)/DATEDIFF(s, b.cached_time, GETDATE())) AS CallsPerSecond
	,((b.total_worker_time/(b.ExecCount*1.0))/1000000) AS AvgWorkerTimeInSecondsPerExec
FROM base b
INNER JOIN sys.objects o ON o.[object_id] = b.[object_id]
INNER JOIN sys.schemas s ON s.[schema_id] = o.[schema_id]
WHERE o.[type] IN ('FN','IF','TF','P')
	AND o.is_ms_shipped <> 1
	AND b.rn = 1;
