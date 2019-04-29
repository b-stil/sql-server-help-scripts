
/******** Table and View Activity based on index so could have multiple rows for same object_id *********/

/**** Ratio of table/view index usage ****/
SELECT
	DB_NAME(st.database_id) AS DatabaseName
	,SCHEMA_NAME(o.[schema_id]) AS SchemaName
	,o.[name] AS ObjectName
	,CASE
		WHEN o.[type] = 'U' THEN 'Table'
		WHEN o.[type] = 'V' THEN 'View'
	END AS ObjectType
	,ISNULL((st.user_seeks/NULLIF((st.user_seeks + st.user_scans + st.user_lookups), 0) * 100.0), 0) AS UserSeek_Pct 
	,ISNULL((st.user_scans/NULLIF((st.user_seeks + st.user_scans + st.user_lookups), 0) * 100.0), 0) AS UserScan_Pct
	,ISNULL((st.user_lookups/NULLIF((st.user_seeks + st.user_scans + st.user_lookups), 0) * 100.0), 0) AS UserLookup_Pct
	,st.user_updates AS UserUpdateQueryCount
	,(SELECT MAX(u)
		FROM (VALUES (st.last_user_seek),(st.last_user_scan),(st.last_user_lookup),(st.last_user_update)) AS value(u)) AS LastAccessedByUserOpDT
FROM sys.dm_db_index_usage_stats st
INNER JOIN sys.objects o ON o.[object_id] = st.[object_id]
WHERE o.[type] IN ('U','V')
	AND database_id = DB_ID() /* current db context for query */
	and o.is_ms_shipped <> 1;


/**** Generalized summary of table/view index usage ****/
SELECT 
	DB_NAME(st.database_id) AS DatabaseName
	,SCHEMA_NAME(o.[schema_id]) AS SchemaName
	,o.[name] AS ObjectName
	,SUM(st.user_seeks + st.user_scans + st.user_lookups) AS NumberOfQueriesAgainstTable
FROM sys.dm_db_index_usage_stats st
INNER JOIN sys.objects o ON o.[object_id] = st.[object_id]
WHERE o.[type] IN ('U','V')
	AND database_id = DB_ID() /* current db context for query */
	and o.is_ms_shipped <> 1
GROUP BY st.database_id, o.[schema_id], o.[name]
