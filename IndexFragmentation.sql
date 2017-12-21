

/* Determine index fragmentation by database */
DECLARE @DatabaseName VARCHAR(100) = '';

SELECT 
	dbschemas.[name] as schemaName
	,dbtables.[name] as tableName
	,dbindexes.[name] as indexName
	,indexstats.avg_fragmentation_in_percent
	,indexstats.page_count
FROM sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL, NULL, NULL) AS indexstats
INNER JOIN sys.tables dbtables on dbtables.[object_id] = indexstats.[object_id]
INNER JOIN sys.schemas dbschemas on dbtables.[schema_id] = dbschemas.[schema_id]
INNER JOIN sys.indexes AS dbindexes ON dbindexes.[object_id] = indexstats.[object_id]
	AND indexstats.index_id = dbindexes.index_id
WHERE indexstats.database_id = DB_ID(@DatabaseName)
ORDER BY indexstats.avg_fragmentation_in_percent DESC;


/********************************************************************/

/* Determine index fragmentation by database and table */
DECLARE @DatabaseName VARCHAR(100) = '';
DECLARE @TableName VARCHAR(128) = '';

SELECT 
	dbschemas.[name] as schemaName
	,dbtables.[name] as tableName
	,dbindexes.[name] as indexName
	,indexstats.avg_fragmentation_in_percent
	,indexstats.page_count
FROM sys.dm_db_index_physical_stats (DB_ID(@DatabaseName), OBJECT_ID(@TableName), NULL, NULL, NULL) AS indexstats
INNER JOIN sys.tables dbtables on dbtables.[object_id] = indexstats.[object_id]
INNER JOIN sys.schemas dbschemas on dbtables.[schema_id] = dbschemas.[schema_id]
INNER JOIN sys.indexes AS dbindexes ON dbindexes.[object_id] = indexstats.[object_id]
	AND indexstats.index_id = dbindexes.index_id
ORDER BY indexstats.avg_fragmentation_in_percent DESC;
