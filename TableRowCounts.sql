/* Count based on number of rows for the main index on the table */
;WITH base AS (
	SELECT 
		SCHEMA_NAME(t.schema_id) AS SchemaName 
		,t.[name] AS TableName
		,i.rowcnt AS NumRows
		,ROW_NUMBER() OVER (PARTITION BY i.id ORDER BY i.indid ASC) AS rn
	FROM sys.tables t
	INNER JOIN sys.sysindexes i ON t.object_id = i.id
)
SELECT
	b.SchemaName
	,b.TableName
	,b.NumRows
FROM base b
WHERE b.rn = 1;
