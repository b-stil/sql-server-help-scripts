
DECLARE @Schema VARCHAR(128) = '';
DECLARE @TableName VARCHAR(128) = ''


DECLARE @Results TABLE(
	SchemaName VARCHAR(128) NOT NULL
	,TableName VARCHAR(128) NOT NULL
	,ReferencedBy VARCHAR(128) NOT NULL
);	
	

DECLARE tab_cur CURSOR FOR
SELECT 
	s.[name]
	,o.[name]
FROM sys.objects o
INNER JOIN sys.schemas s ON s.[schema_id] = o.[schema_id]
WHERE o.[type] = 'U';

OPEN tab_cur;
FETCH NEXT FROM tab_cur INTO @Schema, @TableName;

WHILE @@FETCH_STATUS = 0
BEGIN
	
	INSERT INTO @Results (SchemaName, TableName, ReferencedBy)
	SELECT 
		referencing_schema_name
		,@TableName AS TableName
		,referencing_entity_name AS referencing_object_name
	FROM sys.dm_sql_referencing_entities (@Schema + '.' + @TableName, 'OBJECT')
	UNION
	SELECT
		SCHEMA_NAME(o.SCHEMA_ID) AS referencing_schema_name
		,@TableName AS TableName
		,o.[name] AS referencing_object_name
	FROM sys.sql_expression_dependencies sed
	INNER JOIN sys.objects o ON sed.referencing_id = o.[object_id]
	LEFT OUTER JOIN sys.objects o1 ON sed.referenced_id = o1.[object_id]
	WHERE referenced_entity_name = @TableName;

	FETCH NEXT FROM tab_cur INTO @Schema, @TableName;

END

CLOSE tab_cur;
DEALLOCATE tab_cur;

/* Comma delimited list of references for each Table */
--SELECT DISTINCT 
--	r.SchemaName
--	,r.TableName
--	,Details
--FROM @Results r
--CROSS APPLY (
--	SELECT STUFF((
--		SELECT
--			', ' + ReferencedBy
--		FROM @Results i
--		WHERE i.SchemaName = r.SchemaName AND i.TableName = r.TableName
--		FOR XML PATH('')), 1, 1, '')
--) D (Details)



/* Number of References */
--SELECT 
--	r.SchemaName
--	,r.TableName
--	,COUNT(r.ReferencedBy) AS Num
--FROM @Results r
--GROUP BY r.SchemaName, r.TableName;



/* Tables that aren't reference by procs or functions*/
SELECT
	SCHEMA_NAME(o.schema_id) AS SchemaName
	,o.[name] AS TableName
FROM sys.objects o
WHERE o.[type] = 'U'
EXCEPT
SELECT DISTINCT
	r.SchemaName
	,r.TableName
FROM @Results r;



/* Distinct list of tables referenced by procs or funcs */
--SELECT DISTINCT 
--	r.SchemaName
--	,r.TableName
--FROM @Results r;

