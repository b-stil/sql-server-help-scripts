
/* Find Table Type based on column name */

DECLARE @ColName VARCHAR(100) = '';

SELECT 
	t.name AS TableType
	,c.name AS ColName
	,p.name
	,c.max_length
	,CASE WHEN c.is_nullable = 1 THEN 'NULL' ELSE 'NOT NULL' END AS Nullable
FROM sys.table_types t
INNER JOIN sys.objects o ON o.object_id = t.type_table_object_id
INNER JOIN sys.columns c ON c.object_id = o.object_id
INNER JOIN sys.types p ON c.system_type_id = p.system_type_id
WHERE c.[Name] LIKE '%' + @ColName + '%'

