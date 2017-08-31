
DECLARE @Schema VARCHAR(20) = 'dbo';
DECLARE @TableName VARCHAR(100) = ''

SELECT 
    referencing_schema_name
	,referencing_entity_name
	,referencing_id
	,referencing_class_desc
	,is_caller_dependent
FROM sys.dm_sql_referencing_entities (@Schema + '.' + @TableName, 'OBJECT');


SELECT
	SCHEMA_NAME(o.SCHEMA_ID) AS referencing_schema_name
	,o.[name] AS referencing_object_name
	,o.[type_desc] AS referencing_object_type_desc
	,referenced_schema_name
	,referenced_entity_name AS referenced_object_name
	,o1.[type_desc] AS referenced_object_type_desc
	,referenced_server_name
	,referenced_database_name
	--,sed.* -- Uncomment if you want to see everything, the above should be enough for most things
FROM sys.sql_expression_dependencies sed
INNER JOIN sys.objects o ON sed.referencing_id = o.[object_id]
LEFT OUTER JOIN sys.objects o1 ON sed.referenced_id = o1.[object_id]
WHERE referenced_entity_name = @TableName;
