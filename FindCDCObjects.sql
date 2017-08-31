
/* Find CDC tables that were left behind */
SELECT  QUOTENAME(SCHEMA_NAME(s.schema_id))+'.'+ QUOTENAME(t.name) AS name
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = 'cdc'

/* Find the cdc stored procedures */
SELECT  QUOTENAME(SCHEMA_NAME(s.schema_id))+'.'+ QUOTENAME(pr.name) AS name
FROM    sys.procedures pr
JOIN sys.schemas s ON pr.schema_id = s.schema_id
WHERE   s.name = 'cdc'

/* Find the cdc Functions */
SELECT  CAST((QUOTENAME(SCHEMA_NAME(s.schema_id))+'.'+ QUOTENAME(fn.name)) AS NVARCHAR(MAX)) AS name
FROM    sys.objects fn
JOIN sys.schemas s ON fn.schema_id = s.schema_id
WHERE   fn.type IN ( 'FN', 'IF', 'TF' )
AND s.name = 'cdc'

