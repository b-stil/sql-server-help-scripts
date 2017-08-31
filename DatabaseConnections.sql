
/* Performance counter of the number of user connections to the instance (decimal cntr_value) */
SELECT *
FROM sys.dm_os_performance_counters
WHERE counter_name ='User Connections'

/* Performance counter of the number of logical connections to the instance (decimal cntr_value) */
SELECT * 
FROM sys.dm_os_performance_counters
WHERE counter_name ='Logical Connections'

/* All performance counters with 'connection' in the counter_name  */
SELECT 
	[object_name]
	,counter_name
	,instance_name
	,cntr_value
	,CASE cntr_type
		WHEN 65792 THEN 'Exact'
		WHEN 65536 THEN 'Exact'
		WHEN 272696320 THEN 'Average Per Second'
		WHEN 272696576 THEN 'Average Per Second'
		END AS counter_type
FROM sys.dm_os_performance_counters
WHERE counter_name LIKE '%connection%'


/* What connections are active and WHERE they are coming FROM? */
SELECT 
    DB_NAME(dbid) as DBName, 
    --COUNT(dbid) as NumberOfConnections,
    login_time AS LoginTime,
	last_batch AS LastTimeExecuted,
	loginame as LoginName,
	spid,
	hostname,
	program_name,
	cmd,
    cpu,
	waitresource
FROM
    sys.sysprocesses
WHERE 
    dbid > 0
ORDER BY DBName asc

--GROUP BY 
  --  dbid, loginame


/* Rollup count of all connections to databases on a server instance */
SELECT 
    DB_NAME(dbid) as DBName, 
    COUNT(dbid) as NumberOfConnections
FROM
    sys.sysprocesses
WHERE 
    dbid > 0
GROUP BY 
	dbid
