
SELECT 
	SCHEMA_NAME(t.schema_id) AS SchemaName 
	, t.name AS TableName
	,i.rowcnt AS Rows
FROM sys.tables t
INNER JOIN sys.sysindexes i ON t.object_id = i.id
WHERE i.indid = 1


