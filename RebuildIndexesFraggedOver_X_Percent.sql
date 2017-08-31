DECLARE @DatabaseName VARCHAR(100) = '';
DECLARE @TableName VARCHAR(MAX);
DECLARE @stmt NVARCHAR(MAX);

DECLARE IndexCursor CURSOR FOR
SELECT
	dbschemas.[name] + '.' + dbtables.[name] as 'TableName'
FROM sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL, NULL, NULL) AS indexstats
INNER JOIN sys.tables dbtables on dbtables.[object_id] = indexstats.[object_id]
INNER JOIN sys.schemas dbschemas on dbtables.[schema_id] = dbschemas.[schema_id]
INNER JOIN sys.indexes AS dbindexes ON dbindexes.[object_id] = indexstats.[object_id]
AND indexstats.index_id = dbindexes.index_id
WHERE indexstats.database_id = DB_ID(@DatabaseName) AND indexstats.avg_fragmentation_in_percent > 50.0 AND dbschemas.[name] NOT IN ('cdc','Audit')
ORDER BY indexstats.avg_fragmentation_in_percent DESC

OPEN IndexCursor
FETCH NEXT FROM IndexCursor INTO @TableName

WHILE (@@FETCH_STATUS = 0)
BEGIN
	PRINT N'Index Rebuild for Table: ' + @TableName;
	SET @stmt = 'ALTER INDEX ALL ON ' + @TableName + ' REBUILD WITH (ONLINE = ON);'
	EXECUTE sp_executesql @stmt;

	FETCH NEXT FROM IndexCursor INTO @TableName;
END

CLOSE IndexCursor;
DEALLOCATE IndexCursor;
