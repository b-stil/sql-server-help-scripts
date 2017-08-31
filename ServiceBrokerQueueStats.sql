
DECLARE @DatabaseName VARCHAR(100) = '';
DECLARE @SSBQueue VARCHAR(100) = '';

SELECT 
	s.[name] AS [Service_Name]
	,sc.[name] AS [Schema_Name]
	,sq.[name] AS [Queue_Name]
	,CASE WHEN qm.[state] IS NULL THEN 'Not available' ELSE qm.[state] END AS [Queue_State]
	,CASE WHEN qm.tasks_waiting IS NULL THEN '--' ELSE CONVERT(VARCHAR, qm.tasks_waiting) END AS tasks_waiting
	,CASE WHEN qm.last_activated_time IS NULL THEN '--' ELSE qm.last_activated_time END AS last_activated_time
	,CASE WHEN qm.last_empty_rowset_time IS NULL THEN '--' ELSE qm.last_empty_rowset_time END AS last_empty_rowset_time
	,(SELECT COUNT(*) FROM sys.transmission_queue tq WHERE (tq.from_service_name = s.[name]) ) AS [Tran_Message_Count]
FROM sys.services s
INNER JOIN sys.service_queues sq ON ( s.service_queue_id = sq.[object_id] )
INNER JOIN sys.schemas sc ON ( sq.[schema_id] = sc.[schema_id] )
LEFT OUTER JOIN sys.dm_broker_queue_monitors qm ON ( sq.[object_id] = qm.queue_id  AND qm.database_id = DB_ID()) 
INNER JOIN sys.databases d ON ( d.database_id = DB_ID(@DatabaseName))
WHERE sq.name = @SSBQueue;
