/* When trying to determine what is happening in the database from a blocking perspective
*  it is helpful to check a few things before assuming the blocking is comming from an active user session. */

/* Step 1. Check and see if there is an open transaction that is stuck or ongoing. */
DBCC OPENTRAN

/* Step 2. Check and make sure that the log didn't fill up. There should be external monitoring on this but even that can fail. */
DBCC SQLPERF(LOGSPACE)

/* Step 3. If replication or change data capture (CDC) is enabled then check and see if that is causing the blocking because it is waiting to write/backup the log. */
SELECT
	[name] as db
	,is_cdc_enabled
	,CASE
		WHEN COALESCE(NULLIF(is_published, 0), NULLIF(is_subscribed, 0), NULLIF(is_merge_published, 0), NULLIF(is_distributor, 0)) IS NULL THEN 0
		ELSE 1
	 END AS is_replication_enabled
	,log_reuse_wait_desc
FROM sys.databases


/* Step 4. See if a session is stuck or blocking. */
/* System stored procedure to show activity, sometimes helpful but usually not */
exec sp_who2

/* More detail on the current database sessions. */
SELECT
DB_NAME(req.database_id) AS DBName,
req.session_id,
req.blocking_session_id,
sqltext.TEXT AS SQLCommand,
req.open_transaction_count,
req.status,
req.command,
req.cpu_time,
req.total_elapsed_time
FROM sys.dm_exec_requests req
CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS sqltext
--WHERE req.session_id = 81   
ORDER BY req.database_id;


/* Even more detail on the current database sessions. */
SELECT r.session_id,
r.blocking_session_id,
DB_NAME(r.database_id) AS Database_Name,
s.host_name,
s.login_name,
s.original_login_name,
r.status,
r.command,
r.cpu_time,
r.total_elapsed_time,
t.text as Query_Text
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(sql_handle) t
INNER JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id
ORDER BY r.database_id, r.session_id;


/* Filters out system connections (Service Broker Queue stuff mostly) */
SELECT r.session_id,
r.blocking_session_id,
DB_NAME(r.database_id) AS Database_Name,
s.host_name,
s.login_name,
s.original_login_name,
r.status,
r.command,
r.cpu_time,
r.total_elapsed_time,
t.text as Query_Text
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(sql_handle) t
INNER JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id
WHERE r.blocking_session_id <> 0
ORDER BY r.database_id;


/* Find only the sessions that have open transactions */
SELECT 
DB_NAME(dbid) AS DB
,spid AS SessionID
,blocked AS BlockerID
,open_tran AS NumTrans
,lastwaittype
,waittime
,status
,hostname
,loginame
FROM master.sys.sysprocesses
WHERE open_tran != 0;


/* This may cause blocking itself, hence the 'TOP', so use with caution. 
*  Performs a rollup of the executed queries with some statistics of their use.
*/
SELECT DISTINCT TOP 10
t.TEXT QueryName,
s.execution_count AS ExecutionCount,
s.max_elapsed_time AS MaxElapsedTime,
ISNULL(s.total_elapsed_time / 1000 / NULLIF(s.execution_count, 0), 0) AS AvgElapsedTime,
s.creation_time AS LogCreatedOn,
ISNULL(s.execution_count / 1000 / NULLIF(DATEDIFF(s, s.creation_time, GETDATE()), 0), 0) AS FrequencyPerSec
FROM sys.dm_exec_query_stats s
CROSS APPLY sys.dm_exec_sql_text( s.sql_handle ) t
ORDER BY 
	s.max_elapsed_time DESC
	,ExecutionCount DESC;

