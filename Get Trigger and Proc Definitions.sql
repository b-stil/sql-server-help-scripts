
/* Get trigger definitions */
DECLARE @TriggerName VARCHAR(100) = 'IUD';

--May overflow
SELECT REPLACE(
	STUFF(
		(SELECT '-----------------' + m.definition
		FROM sys.triggers t
		INNER JOIN sys.sql_modules m ON m.object_id = t.object_id
		WHERE t.name LIKE '%' + @TriggerName + '%'
		FOR XML PATH('')), 1, 2, '')
	, '&#x0D;', '');


SELECT 
	t.name
	,m.definition
FROM sys.triggers t
INNER JOIN sys.sql_modules m ON m.object_id = t.object_id
WHERE t.name LIKE '%' + @TriggerName + '%';


/* Get procedure definitions */
DECLARE @SchemaName VARCHAR(50) = '';
DECLARE @ProcName VARCHAR(100) = '';

--May overflow
SELECT CAST(REPLACE(
	STUFF((
		SELECT '-----------------' + m.definition
		FROM sys.procedures p
		INNER JOIN sys.sql_modules m ON m.object_id = p.object_id
		INNER JOIN sys.schemas s ON s.schema_id = p.schema_id
		WHERE s.name = 'Sync'
			AND p.name LIKE '%' + @ProcName + '%'
		FOR XML PATH('')), 1, 2, '')
	, '&#x0D;', '') AS NVARCHAR(MAX));


SELECT p.name, m.definition
FROM sys.procedures p
INNER JOIN sys.sql_modules m ON m.object_id = p.object_id
INNER JOIN sys.schemas s ON s.schema_id = p.schema_id
WHERE s.name = @SchemaName
	AND p.name LIKE '%' + @ProcName + '%';
