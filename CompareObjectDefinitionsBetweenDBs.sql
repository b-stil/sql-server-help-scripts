/***********************************************************************
*
* Compare a Source Database to a Target
*
*
*
***********************************************************************/

/**********************************/
/*<<<<<<< EXECUTION MODES >>>>>>>>*/
/**********************************/
/* @Debug
*		1: Will print SQL statements without full execution
*		0: Will run the script for realsies
*/
DECLARE @Debug BIT = 1;

/* @CleanUp
*		1: Will remove the result tables
*		0: Will run the script as intended
*/
DECLARE @CleanUp BIT = 0;


/**** Set the Database that will be used as the baseline for the comparisons ****/
DECLARE @DatabaseForSourceComparison NVARCHAR(128) = N'';
DECLARE @TargetDatabaseSearchString VARCHAR(20) = ''; /* Used to find the database Targets from catalog to compare against Source */
DECLARE @ResultsDB VARCHAR(128) = 'Results';
DECLARE @ResultsSchema VARCHAR(128) = 'dbo';
DECLARE @TargetDB VARCHAR(128) = '';
DECLARE @ResultsTableName VARCHAR(400) = '';
DECLARE @SqlBlock NVARCHAR(MAX) = '';

/**************<INIT>*****************/
/******* FIND THE DBs TO CHECK *******/
/*************************************/

DECLARE targetDbs_cur CURSOR FOR
	SELECT [name]
	FROM sys.databases 
	WHERE [name] LIKE '%' + LTRIM(RTRIM(@TargetDatabaseSearchString)) + '%' AND [name] <>  LTRIM(RTRIM(@DatabaseForSourceComparison));

OPEN targetDbs_cur;
FETCH NEXT FROM targetDbs_cur INTO @TargetDB;

DECLARE @tabs TABLE (
	SchemaName VARCHAR(128)
	,ObjectName VARCHAR(128)
	,ObjectType VARCHAR(10)
);

WHILE @@FETCH_STATUS = 0
BEGIN
	
	/******** Define the result table to hold comparison data **********/
	SET @ResultsTableName = @ResultsDB + '.' + @ResultsSchema + '.' + @DatabaseForSourceComparison + '_vs_' + @TargetDB;
	IF @Debug = 1
	BEGIN
		PRINT N'*****' + CHAR(13) + '** Results Table: ' + @ResultsTableName +' **' + CHAR(13) + '*****' + CHAR(13);
	END
	

	/***************************************/
	/******* FIND THE MISSING TABLES *******/
	/***************************************/
	SET @SqlBlock = N'IF EXISTS(SELECT 1 FROM ' + @ResultsDB +'.sys.objects WHERE object_id = object_id(N''' + @ResultsTableName + '_MissingTablesViews''))
			BEGIN
				DROP TABLE ' + @ResultsTableName + '_MissingTablesViews; 
			END';
	
	IF @Debug = 1
		PRINT @SqlBlock + CHAR(13);
	ELSE
		EXEC(@SqlBlock);

	SET @SqlBlock = N'CREATE TABLE ' + @ResultsTableName + '_MissingTablesViews (
		SchemaName VARCHAR(128) NOT NULL
		,ObjectName VARCHAR(128) NOT NULL
		,ObjectType VARCHAR(10) NOT NULL
		,MissingInSource BIT NOT NULL
		,MissingInTarget BIT NOT NULL);';

	IF @Debug = 1
		PRINT @SqlBlock + CHAR(13);
	ELSE
		IF @Cleanup = 0
			EXEC(@SqlBlock);
	
	/***** Compare the databases for tables and views that are missing *****/
	SET @SqlBlock = N'INSERT INTO ' + @ResultsTableName + '_MissingTablesViews (SchemaName,ObjectName,ObjectType,MissingInSource,MissingInTarget)
					  SELECT 
							ISNULL(o1.SchemaName, o2.SchemaName) AS SchemaName
							,ISNULL(o1.ObjectName, o2.ObjectName) AS ObjectName
							,CASE
								WHEN ISNULL(o1.ObjectType, o2.ObjectType) = ''U'' THEN ''TABLE''
								WHEN ISNULL(o1.ObjectType, o2.ObjectType) = ''V'' THEN ''VIEW''
							END AS ObjectType
							,CASE 
								WHEN o1.ObjectName IS NULL THEN 1
								ELSE 0
							END AS MissingInSource
							,CASE 
								WHEN o2.ObjectName IS NULL THEN 1
								ELSE 0
							END AS MissingInTarget
						FROM (
							SELECT 
								s1.[name] AS SchemaName
								,o1.[name]	AS ObjectName
								,o1.[type] AS ObjectType
							FROM [' + @DatabaseForSourceComparison + '].sys.objects o1
							INNER JOIN [' + @DatabaseForSourceComparison + '].sys.schemas s1 ON s1.[schema_id] = o1.[schema_id]
							WHERE o1.[type] IN (''U'',''V'')
									AND o1.is_ms_shipped <> 1
						) AS o1
						FULL OUTER JOIN (
								SELECT
									s2.[name] AS SchemaName
									,o2.[name] AS ObjectName
									,o2.[type] AS ObjectType
								FROM [' + @TargetDB + '].sys.objects o2
								INNER JOIN [' + @TargetDB + '].sys.schemas s2 ON s2.[schema_id] = o2.[schema_id]
								WHERE o2.[type] IN (''U'',''V'')
									AND o2.is_ms_shipped <> 1
						) AS o2 ON o2.ObjectName = o1.ObjectName AND o2.ObjectType = o1.ObjectType
						WHERE o1.ObjectName IS NULL OR o2.ObjectName IS NULL
						ORDER BY ObjectName ASC;';
	
	PRINT N'** Missing Tables and Views **' + CHAR(13);
	IF @Debug = 1
		PRINT @SqlBlock + CHAR(13);	
	ELSE
		IF @Cleanup = 0
			EXEC(@SqlBlock);

	PRINT N'******************************' + CHAR(13);


	/**********************************************/
	/******* Compare Constraints and Indexes ******/
	/**********************************************/

	SET @SqlBlock = N'IF EXISTS(SELECT 1 FROM ' + @ResultsDB +'.sys.objects WHERE object_id = object_id(N''' + @ResultsTableName + '_ConstraintsIndexes''))
			BEGIN
				DROP TABLE ' + @ResultsTableName + '_ConstraintsIndexes; 
			END';
	
	IF @Debug = 1
		PRINT @SqlBlock + CHAR(13);
	ELSE
		EXEC(@SqlBlock);

	SET @SqlBlock = N'CREATE TABLE ' + @ResultsTableName + '_ConstraintsIndexes (
		SchemaName VARCHAR(128) NOT NULL
		,ObjectName VARCHAR(128) NOT NULL
		,ObjectType VARCHAR(10) NOT NULL
		,ConstraintName VARCHAR(128) NOT NULL
		,ConstraintType VARCHAR(32) NOT NULL
		,MissingFromSource BIT NOT NULL
		,MissingFromTarget BIT NOT NULL
		,Details VARCHAR(256) NULL);';

	IF @Debug = 1
		PRINT @SqlBlock + CHAR(13);	
	ELSE
		IF @Cleanup = 0
			EXEC(@SqlBlock);
	
	/******** Primary Keys and Unique Indexes *********/
	SET @SqlBlock = N'INSERT INTO ' + @ResultsTableName + '_ConstraintsIndexes (SchemaName,ObjectName,ObjectType,ConstraintName,ConstraintType,MissingFromSource,MissingFromTarget,Details)
						SELECT
							ISNULL(S.SchemaName, T.SchemaName) AS SchemaName
							,ISNULL(S.ObjectName, T.ObjectName) AS ObjectName
							,ISNULL(S.ObjectType, T.ObjectType) AS ObjectType
							,ISNULL(S.ConstraintName, T.ConstraintName) AS ConstraintName
							,ISNULL(S.ConstraintType, T.ConstraintType) AS ConstraintType
							,CASE 
								WHEN S.ObjectName IS NULL THEN 1
								ELSE 0
							END AS MissingFromSource
							,CASE
								WHEN T.ObjectName IS NULL THEN 1
								ELSE 0
							END AS MissingFromTarget
							,ISNULL(S.Details, T.Details) AS Details
						FROM (
							SELECT
								s.[name] AS SchemaName
								,t.[name] AS ObjectName
								,CASE
									WHEN t.[type] = ''U'' THEN ''Table''
									WHEN t.[type] = ''V'' THEN ''View''
								END AS ObjectType
								,CASE
									WHEN c.[type] = ''PK'' THEN ''Primary Key''
									WHEN c.[type] = ''UQ'' THEN ''Unique Index''
									WHEN i.[type] = 1 THEN ''Unique Clustered Index''
									WHEN i.[type] = 2 THEN ''Unique Index''
								END AS ConstraintType
								,ISNULL(c.[name], i.[name]) AS ConstraintName
								,Details
							FROM [' + @DatabaseForSourceComparison + '].sys.objects t
							INNER JOIN [' + @DatabaseForSourceComparison + '].sys.schemas s ON s.[schema_id] = t.[schema_id]
							LEFT OUTER JOIN [' + @DatabaseForSourceComparison + '].sys.indexes i ON i.[object_id] = t.[object_id]
							LEFT OUTER JOIN [' + @DatabaseForSourceComparison + '].sys.key_constraints c ON c.parent_object_id = i.[object_id] AND c.unique_index_id = i.index_id
							CROSS APPLY (
								SELECT STUFF((
									SELECT
										'','' + col.[name]
									FROM [' + @DatabaseForSourceComparison + '].sys.index_columns ic
									INNER JOIN [' + @DatabaseForSourceComparison + '].sys.columns col ON col.[object_id] = ic.[object_id] AND col.column_id = ic.column_id
									WHERE ic.[object_id] = t.[object_id]
										AND ic.index_id = i.index_id
									ORDER BY col.column_id
									FOR XML PATH ('''')), 1, 1, '''')
							) D (Details)
							WHERE i.is_unique = 1
								AND t.is_ms_shipped <> 1
						) AS S
						FULL OUTER JOIN (
							SELECT
								s.[name] AS SchemaName
								,t.[name] AS ObjectName
								,CASE
									WHEN t.[type] = ''U'' THEN ''Table''
									WHEN t.[type] = ''V'' THEN ''View''
								END AS ObjectType
								,CASE
									WHEN c.[type] = ''PK'' THEN ''Primary Key''
									WHEN c.[type] = ''UQ'' THEN ''Unique Index''
									WHEN i.[type] = 1 THEN ''Unique Clustered Index''
									WHEN i.[type] = 2 THEN ''Unique Index''
								END AS ConstraintType
								,ISNULL(c.[name], i.[name]) AS ConstraintName
								,Details
							FROM [' + @TargetDB + '].sys.objects t
							INNER JOIN [' + @TargetDB + '].sys.schemas s ON s.[schema_id] = t.[schema_id]
							LEFT OUTER JOIN [' + @TargetDB + '].sys.indexes i ON i.[object_id] = t.[object_id]
							LEFT OUTER JOIN [' + @TargetDB + '].sys.key_constraints c ON c.parent_object_id = i.[object_id] AND c.unique_index_id = i.index_id
							CROSS APPLY (
								SELECT STUFF((
									SELECT
										'','' + col.[name]
									FROM [' + @TargetDB + '].sys.index_columns ic
									INNER JOIN [' + @TargetDB + '].sys.columns col ON col.[object_id] = ic.[object_id] AND col.column_id = ic.column_id
									WHERE ic.[object_id] = t.[object_id]
										AND ic.index_id = i.index_id
									ORDER BY col.column_id
									FOR XML PATH ('''')), 1, 1, '''')
							) D (Details)
							WHERE i.is_unique = 1
								AND t.is_ms_shipped <> 1
						) AS T ON T.ObjectName = S.ObjectName
						WHERE S.ObjectName IS NULL OR T.ObjectName IS NULL;';
	
	PRINT N'** Primary Keys Unique Indexes **' + CHAR(13);
	IF @Debug = 1
		PRINT @SqlBlock  + CHAR(13);
	ELSE
		IF @Cleanup = 0
			EXEC(@SqlBlock);

	PRINT N'******************************' + CHAR(13);

	/********** Non-Clustered Indexes **********/
	SET @SqlBlock = N'INSERT INTO ' + @ResultsTableName + '_ConstraintsIndexes (SchemaName,ObjectName,ObjectType,ConstraintName,ConstraintType,MissingFromSource,MissingFromTarget,Details)
						SELECT
							ISNULL(S.SchemaName, T.SchemaName) AS SchemaName
							,ISNULL(S.ObjectName, T.ObjectName) AS ObjectName
							,ISNULL(S.ObjectType, T.ObjectType) AS ObjectType
							,ISNULL(S.ConstraintName, T.ConstraintName) AS ConstraintName
							,ISNULL(S.ConstraintType, T.ConstraintType) AS ConstraintType
							,CASE 
								WHEN S.ObjectName IS NULL THEN 1
								ELSE 0
							END AS MissingFromSource
							,CASE
								WHEN T.ObjectName IS NULL THEN 1
								ELSE 0
							END AS MissingFromTarget
							,ISNULL(S.Details, T.Details) AS Details
						FROM (
							SELECT 
								s.[name] AS SchemaName
								,tv.[name] AS ObjectName
								,CASE
									WHEN tv.[type] = ''U'' THEN ''Table''
									WHEN tv.[type] = ''V'' THEN ''View''
									WHEN tv.[type] = ''TF'' THEN ''Function''
									ELSE tv.[type]
								END AS ObjectType
								,ISNULL(i.[name], ''HEAP'') AS ConstraintName
								,CASE
									WHEN i.index_id > 1 THEN ''Index NC''
								END AS ConstraintType
								,ISNULL(Details, '''') AS Details
							FROM [' + @DatabaseForSourceComparison + '].sys.objects tv 
							INNER JOIN [' + @DatabaseForSourceComparison + '].sys.schemas s on s.[schema_id] = tv.[schema_id]
							INNER JOIN [' + @DatabaseForSourceComparison + '].sys.indexes i on i.[object_id] = tv.[object_id]
							CROSS APPLY (
								SELECT STUFF((
									SELECT
										'','' + col.[name]
									FROM [' + @DatabaseForSourceComparison + '].sys.index_columns ic
									INNER JOIN [' + @DatabaseForSourceComparison + '].sys.columns col ON col.[object_id] = ic.[object_id] AND col.column_id = ic.column_id
									WHERE ic.[object_id] = tv.[object_id]
										AND ic.index_id = i.index_id
									ORDER BY col.column_id
									FOR XML PATH ('''')), 1, 1, '''')
							) D (Details)
							WHERE i.is_primary_key = 0
								AND i.is_unique = 0
								AND i.is_unique_constraint = 0
								AND i.[type] > 1
								AND tv.is_ms_shipped <> 1
						) AS S
						FULL OUTER JOIN (
							SELECT 
								s.[name] AS SchemaName
								,tv.[name] AS ObjectName
								,CASE
									WHEN tv.[type] = ''U'' THEN ''Table''
									WHEN tv.[type] = ''V'' THEN ''View''
									WHEN tv.[type] = ''TF'' THEN ''Function''
									ELSE tv.[type]
								END AS ObjectType
								,ISNULL(i.[name], ''HEAP'') AS ConstraintName
								,CASE
									WHEN i.index_id > 1 THEN ''Index NC''
								END AS ConstraintType
								,ISNULL(Details, '''') AS Details
							FROM [' + @TargetDB + '].sys.objects tv 
							INNER JOIN [' + @TargetDB + '].sys.schemas s on s.[schema_id] = tv.[schema_id]
							INNER JOIN [' + @TargetDB + '].sys.indexes i on i.[object_id] = tv.[object_id]
							CROSS APPLY (
								SELECT STUFF((
									SELECT
										'','' + col.[name]
									FROM [' + @TargetDB + '].sys.index_columns ic
									INNER JOIN [' + @TargetDB + '].sys.columns col ON col.[object_id] = ic.[object_id] AND col.column_id = ic.column_id
									WHERE ic.[object_id] = tv.[object_id]
										AND ic.index_id = i.index_id
									ORDER BY col.column_id
									FOR XML PATH ('''')), 1, 1, '''')
							) D (Details)
							WHERE i.is_primary_key = 0
								AND i.is_unique = 0
								AND i.is_unique_constraint = 0
								AND i.[type] > 1
								AND tv.is_ms_shipped <> 1
						) AS T ON T.ObjectName = S.ObjectName
						WHERE S.ObjectName IS NULL OR T.ObjectName IS NULL;';

	PRINT N'** Non-Clustered Indexes **' + CHAR(13);
	IF @Debug = 1
		PRINT @SqlBlock  + CHAR(13);
	ELSE
		IF @Cleanup = 0
			EXEC(@SqlBlock);

	PRINT N'******************************' + CHAR(13);

	/***** Foreign Keys  ******/
	SET @SqlBlock = N'INSERT INTO ' + @ResultsTableName + '_ConstraintsIndexes (SchemaName,ObjectName,ObjectType,ConstraintName,ConstraintType,MissingFromSource,MissingFromTarget,Details)
						SELECT
							ISNULL(S.SchemaName, T.SchemaName) AS SchemaName
							,ISNULL(S.ObjectName, T.ObjectName) AS ObjectName
							,ISNULL(S.ObjectType, T.ObjectType) AS ObjectType
							,ISNULL(S.ConstraintName, T.ConstraintName) AS ConstraintName
							,ISNULL(S.ConstraintType, T.ConstraintType) AS ConstraintType
							,CASE 
								WHEN S.ObjectName IS NULL THEN 1
								ELSE 0
							END AS MissingFromSource
							,CASE
								WHEN T.ObjectName IS NULL THEN 1
								ELSE 0
							END AS MissingFromTarget
							,ISNULL(S.Details, T.Details) AS Details
						FROM (
							SELECT 
								s.[name] AS SchemaName
								,tf.[name] AS ObjectName
								,f.[name] AS ConstraintName
								,''Table'' AS ObjectType
								,''Foreign Key'' AS ConstraintType
								,tp.[name] + ''.'' + c.[name] AS Details
							FROM [' + @DatabaseForSourceComparison + '].sys.foreign_keys f
							INNER JOIN [' + @DatabaseForSourceComparison + '].sys.tables tf ON tf.[object_id] = f.parent_object_id
							INNER JOIN [' + @DatabaseForSourceComparison + '].sys.tables tp ON tp.[object_id] = f.referenced_object_id
							INNER JOIN [' + @DatabaseForSourceComparison + '].sys.foreign_key_columns fc ON fc.constraint_object_id = f.[object_id]
							INNER JOIN [' + @DatabaseForSourceComparison + '].sys.columns c ON c.column_id = fc.parent_column_id AND c.[object_id] = fc.parent_object_id
							INNER JOIN [' + @DatabaseForSourceComparison + '].sys.schemas s on s.[schema_id] = f.[schema_id]
						) AS S
						FULL OUTER JOIN (
							SELECT 
								s.[name] AS SchemaName
								,tf.[name] AS ObjectName
								,f.[name] AS ConstraintName
								,''Table'' AS ObjectType
								,''Foreign Key'' AS ConstraintType
								,tp.[name] + ''.'' + c.[name] AS Details
							FROM [' + @TargetDB + '].sys.foreign_keys f
							INNER JOIN [' + @TargetDB + '].sys.tables tf ON tf.[object_id] = f.parent_object_id
							INNER JOIN [' + @TargetDB + '].sys.tables tp ON tp.[object_id] = f.referenced_object_id
							INNER JOIN [' + @TargetDB + '].sys.foreign_key_columns fc ON fc.constraint_object_id = f.[object_id]
							INNER JOIN [' + @TargetDB + '].sys.columns c ON c.column_id = fc.parent_column_id AND c.[object_id] = fc.parent_object_id
							INNER JOIN [' + @TargetDB + '].sys.schemas s on s.[schema_id] = f.[schema_id]
						) AS T ON T.ObjectName = S.ObjectName
						WHERE S.ObjectName IS NULL OR T.ObjectName IS NULL;';
	
	PRINT N'** FKs **' + CHAR(13);
	IF @Debug = 1
		PRINT @SqlBlock + CHAR(13);	
	ELSE
		IF @Cleanup = 0
			EXEC(@SqlBlock);

	PRINT N'******************************' + CHAR(13);

	/*****  Check Constraints *****/
	SET @SqlBlock = N'INSERT INTO ' + @ResultsTableName + '_ConstraintsIndexes (SchemaName,ObjectName,ObjectType,ConstraintName,ConstraintType,MissingFromSource,MissingFromTarget,Details)
						SELECT 
						ISNULL(S.SchemaName, T.SchemaName) AS SchemaName
						,ISNULL(S.ObjectName, T.ObjectName) AS ObjectName
						,ISNULL(S.ObjectType, T.ObjectType) AS ObjectType
						,ISNULL(S.ConstraintName, T.ConstraintName) AS ConstraintName
						,ISNULL(S.ConstraintType, T.ConstraintType) AS ConstraintType
						,CASE 
							WHEN S.ObjectName IS NULL THEN 1
							ELSE 0
						END AS MissingFromSource
						,CASE
							WHEN T.ObjectName IS NULL THEN 1
							ELSE 0
						END AS MissingFromTarget
						,ISNULL(S.Details, T.Details) AS Details
					FROM(
						SELECT 
							s.[name] AS SchemaName
							,t.[name] AS ObjectName
							,con.[name] AS ConstraintName
							,''Table'' AS ObjectType
							,''Check Constraint'' AS ConstraintType
							, con.[definition] AS Details
						FROM [' + @DatabaseForSourceComparison + '].sys.check_constraints con
						INNER JOIN [' + @DatabaseForSourceComparison + '].sys.schemas s on s.[schema_id] = con.[schema_id]
						LEFT OUTER JOIN [' + @DatabaseForSourceComparison + '].sys.objects t ON t.[object_id] = con.parent_object_id
					) AS S
					FULL OUTER JOIN (
						SELECT 
							s.[name] AS SchemaName
							,t.[name] AS ObjectName
							,con.[name] AS ConstraintName
							,''Table'' AS ObjectType
							,''Check Constraint'' AS ConstraintType
							, con.[definition] AS Details
						FROM [' + @TargetDB + '].sys.check_constraints con
						INNER JOIN [' + @TargetDB + '].sys.schemas s on s.[schema_id] = con.[schema_id]
						LEFT OUTER JOIN [' + @TargetDB + '].sys.objects t ON t.[object_id] = con.parent_object_id
					) AS T ON T.ObjectName = S.ObjectName
					WHERE S.ObjectName IS NULL OR T.ObjectName IS NULL;';
	
	PRINT N'** Check Constraints **' + CHAR(13);
	IF @Debug = 1
		PRINT @SqlBlock + CHAR(13);	
	ELSE
		IF @Cleanup = 0
			EXEC(@SqlBlock);

	PRINT N'******************************' + CHAR(13);

	/***** Default Constraints ******/
	SET @SqlBlock = N'INSERT INTO ' + @ResultsTableName + '_ConstraintsIndexes (SchemaName,ObjectName,ObjectType,ConstraintName,ConstraintType,MissingFromSource,MissingFromTarget,Details)
						SELECT 
							ISNULL(S.SchemaName, T.SchemaName) AS SchemaName
							,ISNULL(S.ObjectName, T.ObjectName) AS ObjectName
							,ISNULL(S.ObjectType, T.ObjectType) AS ObjectType
							,ISNULL(S.ConstraintName, T.ConstraintName) AS ConstraintName
							,ISNULL(S.ConstraintType, T.ConstraintType) AS ConstraintType
							,CASE 
								WHEN S.ObjectName IS NULL THEN 1
								ELSE 0
							END AS MissingFromSource
							,CASE
								WHEN T.ObjectName IS NULL THEN 1
								ELSE 0
							END AS MissingFromTarget
							,ISNULL(S.Details, T.Details) AS Details
						FROM(
							SELECT 
								s.[name] AS SchemaName
								,t.[name] AS ObjectName
								,con.[name] AS ConstraintName
								,''Table'' AS ObjectType
								,''Default Constraint'' AS ConstraintType
								,ac.[name] + '' = '' + con.[definition] AS Details
							FROM [' + @DatabaseForSourceComparison + '].sys.default_constraints con
							INNER JOIN [' + @DatabaseForSourceComparison + '].sys.schemas s ON s.[schema_id] = con.[schema_id]
							LEFT OUTER JOIN [' + @DatabaseForSourceComparison + '].sys.objects t ON t.[object_id] = con.parent_object_id
							LEFT OUTER JOIN [' + @DatabaseForSourceComparison + '].sys.all_columns ac ON ac.column_id = con.parent_column_id AND ac.[object_id] = con.parent_object_id
						) AS S
						FULL OUTER JOIN (
							SELECT 
								s.[name] AS SchemaName
								,t.[name] AS ObjectName
								,con.[name] AS ConstraintName
								,''Table'' AS ObjectType
								,''Default Constraint'' AS ConstraintType
								,ac.[name] + '' = '' + con.[definition] AS Details
							FROM [' + @TargetDB + '].sys.default_constraints con
							INNER JOIN [' + @TargetDB + '].sys.schemas s ON s.[schema_id] = con.[schema_id]
							LEFT OUTER JOIN [' + @TargetDB + '].sys.objects t ON t.[object_id] = con.parent_object_id
							LEFT OUTER JOIN [' + @TargetDB + '].sys.all_columns ac ON ac.column_id = con.parent_column_id AND ac.[object_id] = con.parent_object_id
						) AS T ON T.ObjectName = S.ObjectName
						WHERE S.ObjectName IS NULL OR T.ObjectName IS NULL;';

	PRINT N'** Default Constraints **' + CHAR(13);
	IF @Debug = 1
		PRINT @SqlBlock + CHAR(13);	
	ELSE
		IF @Cleanup = 0
			EXEC(@SqlBlock);

	PRINT N'******************************' + CHAR(13);

	
	/*********************************************/
	/****** STORED PROCEDURES AND FUNCTIONS ******/
	/*********************************************/

	SET @SqlBlock = N'IF EXISTS(SELECT 1 FROM ' + @ResultsDB +'.sys.objects WHERE object_id = object_id(N''' + @ResultsTableName + '_FuncsProcs''))
			BEGIN
				DROP TABLE ' + @ResultsTableName + '_FuncsProcs; 
			END';
	
	IF @Debug = 1
		PRINT @SqlBlock + CHAR(13);
	ELSE
		EXEC(@SqlBlock);


	SET @SqlBlock = N'CREATE TABLE ' + @ResultsTableName + '_FuncsProcs (
		SchemaName VARCHAR(128) NOT NULL
		,ObjectName VARCHAR(128) NOT NULL
		,ParameterName VARCHAR(128) NOT NULL
		,ObjectType VARCHAR(10) NOT NULL
		,MissingFromSource BIT NOT NULL
		,MissingFromTarget BIT NOT NULL
		,DataTypeMismatch BIT NOT NULL
		,DataType VARCHAR(50));';

	IF @Debug = 1
		PRINT @SqlBlock + CHAR(13);
	ELSE
		IF @Cleanup = 0
			EXEC(@SqlBlock);
	
	SET @SqlBlock = N'INSERT INTO ' + @ResultsTableName + '_FuncsProcs (SchemaName,ObjectName,ParameterName,ObjectType,MissingFromSource,MissingFromTarget,DataTypeMismatch,DataType)
					  SELECT
							ISNULL(S.SchemaName, T.SchemaName) AS SchemaName
							,ISNULL(S.ObjectName, T.ObjectName) AS ObjectName
							,ISNULL(S.ParameterName, T.ParameterName) AS ParameterName
							,ISNULL(
								CASE
									WHEN S.ObjectName IS NOT NULL AND S.TypeDesc LIKE ''%FUNCTION%'' THEN ''FUNCTION''
									WHEN S.ObjectName IS NOT NULL AND S.TypeDesc LIKE ''%PROCEDURE%'' THEN ''PROCEDURE''
									ELSE NULL
								END
								,
								CASE
									WHEN T.ObjectName IS NOT NULL AND T.TypeDesc LIKE ''%FUNCTION%'' THEN ''FUNCTION''
									WHEN T.ObjectName IS NOT NULL AND T.TypeDesc LIKE ''%PROCEDURE%'' THEN ''PROCEDURE''
									ELSE NULL
								END
								) AS ObjectType
							,CASE
								WHEN S.ObjectName IS NULL THEN 1
								ELSE 0
							END	AS MissingFromSource
							,CASE 
								WHEN T.ObjectName IS NULL THEN 1
								ELSE 0
							END As MissingFromTarget
							,CASE
								WHEN S.ObjectName IS NOT NULL AND T.ObjectName IS NOT NULL AND S.DataType <> T.DataType THEN 1
								ELSE 0
							END AS DataTypeMismatch
							,CASE
								WHEN S.ObjectName IS NOT NULL AND T.ObjectName IS NOT NULL AND S.DataType <> T.DataType THEN S.DataType + '' <=> '' + T.DataType
								ELSE ISNULL(S.DataType, T.DataType)
							END AS DataType
						FROM (
							SELECT 
								s.[name] AS SchemaName
								,o1.[name] AS ObjectName
								,pm.[name] AS ParameterName
								,tp.[name] + ''('' + CAST(pm.max_length AS VARCHAR) + '')'' AS DataType
								,o1.[type_desc] AS TypeDesc
								,pm.has_default_value AS HasDefault
								,ISNULL(CAST(pm.default_value AS VARCHAR), '''') AS DefaultValue
								,pm.is_nullable AS IsNullable
							FROM [' + @DatabaseForSourceComparison + '].sys.objects o1
							INNER JOIN [' + @DatabaseForSourceComparison + '].sys.schemas s ON s.[schema_id] = o1.[schema_id]
							LEFT JOIN [' + @DatabaseForSourceComparison + '].sys.parameters pm ON pm.[object_id] = o1.[object_id]
							LEFT JOIN [' + @DatabaseForSourceComparison + '].sys.types tp ON tp.system_type_id = pm.system_type_id
							WHERE o1.[type] IN (''AF'',''FN'',''FS'',''FT'', ''IF'',''TF'',''P'',''PC'',''RF'',''X'')
								AND pm.is_output <> 1
								AND o1.is_ms_shipped <> 1
						) AS S
						FULL OUTER JOIN (
							SELECT 
								s.[name] AS SchemaName
								,o2.[name] AS ObjectName
								,pm.[name] AS ParameterName
								,tp.[name] + ''('' + CAST(pm.max_length AS VARCHAR) + '')'' AS DataType
								,o2.[type_desc] AS TypeDesc
								,pm.has_default_value AS HasDefault
								,ISNULL(CAST(pm.default_value AS VARCHAR), '''') AS DefaultValue
								,pm.is_nullable AS IsNullable
							FROM [' + @TargetDB + '].sys.objects o2
							INNER JOIN [' + @TargetDB + '].sys.schemas s ON s.[schema_id] = o2.[schema_id]
							LEFT JOIN [' + @TargetDB + '].sys.parameters pm ON pm.[object_id] = o2.[object_id]
							LEFT JOIN [' + @TargetDB + '].sys.types tp ON tp.system_type_id = pm.system_type_id
							WHERE o2.[type] IN (''AF'',''FN'',''FS'',''FT'', ''IF'',''TF'',''P'',''PC'',''RF'',''X'')
								AND pm.is_output <> 1
								AND o2.is_ms_shipped <> 1
						) AS T ON T.SchemaName = S.SchemaName AND T.ObjectName = S.ObjectName AND T.ParameterName = S.ParameterName
						WHERE (T.ParameterName IS NULL OR S.ParameterName IS NULL) OR (T.DataType <> S.DataType)
						ORDER BY SchemaName, ObjectName, ParameterName ASC;';
				  
	
	PRINT N'** Stored Procedures and Functions **' + CHAR(13);
	IF @Debug = 1
		PRINT @SqlBlock + CHAR(13);	
	ELSE
		IF @Cleanup = 0
			EXEC(@SqlBlock);

	PRINT N'******************************' + CHAR(13);
	
	
	/**********************/
	/****** TRIGGERS ******/
	/**********************/

	SET @SqlBlock = N'IF EXISTS(SELECT 1 FROM ' + @ResultsDB +'.sys.objects WHERE object_id = object_id(N''' + @ResultsTableName + '_Triggers''))
			BEGIN
				DROP TABLE ' + @ResultsTableName + '_Triggers; 
			END';
	
	IF @Debug = 1
		PRINT @SqlBlock + CHAR(13);
	ELSE
		EXEC(@SqlBlock);

	SET @SqlBlock = N'CREATE TABLE ' + @ResultsTableName + '_Triggers (
		SchemaName VARCHAR(128) NOT NULL
		,ObjectName VARCHAR(128) NOT NULL
		,ObjectType VARCHAR(10) NOT NULL
		,MissingFromSource BIT NOT NULL
		,MissingFromTarget BIT NOT NULL);';

	IF @Debug = 1
		PRINT @SqlBlock + CHAR(13);
	ELSE
		IF @Cleanup = 0
			EXEC(@SqlBlock);
	
	SET @SqlBlock = N'INSERT INTO ' + @ResultsTableName + '_Triggers (SchemaName,ObjectName,ObjectType,MissingFromSource,MissingFromTarget)
						SELECT 
							ISNULL(o1.SchemaName, o2.SchemaName) AS SchemaName
							,ISNULL(o1.ObjectName, o2.ObjectName) AS ObjectName
							,ISNULL(o1.ObjectType, o2.ObjectType) AS ObjectType
							,CASE 
								WHEN o1.ObjectName IS NULL THEN 1
								ELSE 0
							END AS MissingFromSource
							,CASE 
								WHEN o2.ObjectName IS NULL THEN 1
								ELSE 0
							END AS MissingFromTarget
						FROM (
							SELECT
								s.[name] AS SchemaName
								,tr.[name] AS ObjectName
								,''TRIGGER'' AS ObjectType
							FROM [' + @DatabaseForSourceComparison + '].sys.triggers tr
							INNER JOIN [' + @DatabaseForSourceComparison + '].sys.objects o ON o.[object_id] = tr.parent_id
							INNER JOIN [' + @DatabaseForSourceComparison + '].sys.schemas s on s.[schema_id] = o.[schema_id]
							WHERE tr.is_ms_shipped <> 1
						) AS o1
						FULL OUTER JOIN (
							SELECT
								s.[name] AS SchemaName
								,tr.[name] AS ObjectName
								,''TRIGGER'' AS ObjectType
							FROM [' + @TargetDB + '].sys.triggers tr
							INNER JOIN [' + @TargetDB + '].sys.objects o ON o.[object_id] = tr.parent_id
							INNER JOIN [' + @TargetDB + '].sys.schemas s on s.[schema_id] = o.[schema_id]
							WHERE tr.is_ms_shipped <> 1
						) AS o2 ON o2.ObjectName = o1.ObjectName AND o2.ObjectType = o1.ObjectType
						WHERE o1.ObjectName IS NULL OR o2.ObjectName IS NULL
						ORDER BY ObjectName ASC;';
	
	PRINT N'** Triggers **' + CHAR(13);
	IF @Debug = 1
			PRINT @SqlBlock + CHAR(13);
		ELSE
			IF @Cleanup = 0
				EXEC(@SqlBlock);
	
	PRINT N'******************************' + CHAR(13);


	/***********************************/
	/******* TABLE DEFINITIONS *********/
	/***********************************/
	
	/******* Compare the table definitions between the databases ********/
	SET @SqlBlock = N'IF EXISTS(SELECT 1 FROM ' + @ResultsDB +'.sys.objects WHERE object_id = object_id(N''' + @ResultsTableName + '_TableViewDefs''))
				BEGIN
					DROP TABLE ' + @ResultsTableName + '_TableViewDefs; 
				END';
	
	IF @Debug = 1
		PRINT @SqlBlock + CHAR(13);
	ELSE
		EXEC(@SqlBlock);

	SET @SqlBlock = N'CREATE TABLE ' + @ResultsTableName + '_TableViewDefs (
			SchemaName VARCHAR(128) NOT NULL
			,TableName VARCHAR(128) NOT NULL
			,ColumnName VARCHAR(128) NOT NULL
			,MissingFromSource BIT NOT NULL
			,MissingFromTarget BIT NOT NULL
			,DataTypeMismatch BIT NOT NULL
			,SourceDataType VARCHAR(128) NOT NULL
			,TargetDataType VARCHAR(128) NOT NULL
			,NullableMismatch BIT NOT NULL
			,IdentityMismatch BIT NOT NULL
			,ObjectType VARCHAR(10) NOT NULL);';
	
	IF @Debug = 1
		PRINT @SqlBlock + CHAR(13);
	ELSE
		IF @Cleanup = 0
			EXEC(@SqlBlock);

	/***** Pull all the tables and views that exist in both Source and Target to evaluate definitions *****/
	SET @SqlBlock = N'SELECT 
							s1.[name] AS SchemaName
							,o1.[name] AS ObjectName
							,CASE 
								WHEN o1.[type] = ''U'' THEN ''TABLE''
								WHEN o1.[type] = ''V'' THEN ''VIEW''
							END AS ObjectType
						FROM [' + @DatabaseForSourceComparison + '].sys.objects o1
						INNER JOIN [' + @DatabaseForSourceComparison + '].sys.schemas s1 on s1.[schema_id] = o1.[schema_id]
						WHERE o1.[type] IN (''U'',''V'')
									AND o1.is_ms_shipped <> 1
						INTERSECT 
						SELECT 
							s2.[name] AS SchemaName
							,o2.[name] AS ObjectName
							,CASE 
								WHEN o2.[type] = ''U'' THEN ''TABLE''
								WHEN o2.[type] = ''V'' THEN ''VIEW''
							END AS ObjectType
						FROM [' + @TargetDB + '].sys.objects o2
						INNER JOIN [' + @TargetDB + '].sys.schemas s2 on s2.[schema_id] = o2.[schema_id]
						WHERE o2.[type] IN (''U'',''V'')
									AND o2.is_ms_shipped <> 1;';
	
	PRINT N'** Pull tables in Source and Target for comparison **' + CHAR(13);
	IF @Debug = 1
	BEGIN
		PRINT @SqlBlock + CHAR(13);
		PRINT N'******************************'  + CHAR(13);
	END 

	IF @CleanUp = 0
	BEGIN
		DELETE FROM @tabs; /* Make sure it is empty for each iteration */

		INSERT INTO @tabs
		EXEC(@SqlBlock);

		/***** Iterate the tables to pull definitions *****/
		
		DECLARE @SchemaCheck VARCHAR(128);
		DECLARE @ObjectCheck VARCHAR(256);
		DECLARE @ObjectType VARCHAR(10);

		DECLARE tables_cur CURSOR FOR
		SELECT
			t.SchemaName
			,t.ObjectName
			,t.ObjectType
		FROM @tabs t;

		OPEN tables_cur;
		FETCH NEXT FROM tables_cur INTO @SchemaCheck, @ObjectCheck, @ObjectType;

		WHILE @@FETCH_STATUS = 0
		BEGIN
			PRINT N'*****' + CHAR(13) + '** Extracting definitions for ''' + @ObjectType + ''': ' + @DatabaseForSourceComparison + '.' + @SchemaCheck + '.' + @ObjectCheck + ' to compare with: ' + @TargetDB + '.' + @SchemaCheck + '.' + @ObjectCheck + ' **' + CHAR(13) + '*****' + CHAR(13);

			SET @SqlBlock = N';WITH base AS (
									SELECT
										ISNULL(ISNULL(t1.source_schema, t2.source_schema), ''' + @SchemaCheck + ''' ) AS SchemaName
										,ISNULL(ISNULL(t1.source_table, t2.source_table), ''' + @ObjectCheck + ''') AS TableName
										,t1.[name] AS ColumnName_B
										,t2.[name] AS ColumnName_C
										,t1.system_type_name AS DataType_B
										,t2.system_type_name AS DataType_C
										,t1.is_nullable AS IsNullable_B
										,t2.is_nullable AS IsNullable_C
										,t1.is_identity_column AS IsIdentity_B
										,t2.is_identity_column AS IsIdentity_C
										,''' + @ObjectType + ''' AS ObjectType
									FROM sys.dm_exec_describe_first_result_set (N''SELECT * FROM [' + @DatabaseForSourceComparison + '].[' + @SchemaCheck + '].[' + @ObjectCheck + ']'', NULL, 1) t1
									FULL OUTER JOIN sys.dm_exec_describe_first_result_set(N''SELECT * FROM [' + @TargetDB + '].[' + @SchemaCheck + '].[' + @ObjectCheck + ']'', NULL, 1) t2 
										ON t2.[name] = t1.[name] AND t2.source_table = t1.source_table
									WHERE (t1.[name] IS NULL OR t2.[name] IS NULL) /* Missing columns */
										OR (ISNULL(t1.system_type_name, '''') <> ISNULL(t2.system_type_name, '''')) /* Mismatch Data Type */
										OR ((t1.[name] IS NOT NULL AND t2.[name] IS NOT NULL) AND t1.[precision] <> t2.[precision])
										OR ((t1.[name] IS NOT NULL AND t2.[name] IS NOT NULL) AND t1.is_nullable <> t2.is_nullable) /* Mismatch Nullable only if column exists in both */
										OR ((t1.[name] IS NOT NULL AND t2.[name] IS NOT NULL) AND t1.is_identity_column <> t2.is_identity_column) /* Mismatch Identity only if column exists in both */
								)
								INSERT INTO  ' + @ResultsTableName + '_TableViewDefs (SchemaName,TableName,ColumnName,MissingFromSource,MissingFromTarget,DataTypeMismatch,SourceDataType,TargetDataType,NullableMismatch,IdentityMismatch,ObjectType)
								SELECT
									b.SchemaName
									,b.TableName
									,ISNULL(b.ColumnName_B, b.ColumnName_C) AS ColumnName
									,CASE
										WHEN b.ColumnName_B IS NULL THEN 1
										ELSE 0
									END AS MissingFromSource
									,CASE
										WHEN b.ColumnName_C IS NULL THEN 1
										ELSE 0
									END AS MissingFromTarget
									,CASE
										WHEN ISNULL(b.DataType_B, '''') <> ISNULL(b.DataType_C, '''') THEN 1
										ELSE 0
									END AS DataTypeMismatch
									,ISNULL(b.DataType_B, '''') AS SourceDataType
									,ISNULL(b.DataType_C, '''') AS TargetDataType
									,CASE
										WHEN ISNULL(b.IsNullable_B, '''') <> ISNULL(b.IsNullable_C, '''') THEN 1
										ELSE 0
									END AS NullableMismatch
									,CASE
										WHEN ISNULL(b.IsIdentity_B, '''') <> ISNULL(b.IsIdentity_C, '''') THEN 1
										ELSE 0
									END AS IdentityMismatch
									,b.ObjectType
								FROM base b;';

			IF @Debug = 1
				PRINT @SqlBlock + CHAR(13);
			ELSE
				EXEC(@SqlBlock);

			PRINT N'******************************' + CHAR(13);
			
			/* Get next table to compare definition */
			FETCH NEXT FROM tables_cur INTO @SchemaCheck, @ObjectCheck, @ObjectType;

		END /* tables_cur */
		CLOSE tables_cur;
		DEALLOCATE tables_cur;

	END /* IF @CleanUp = 0 */
	
	/* Get next target database to compare */
	FETCH NEXT FROM targetDbs_cur INTO @TargetDB;

END /* targetDbs_cur */
CLOSE targetDbs_cur;
DEALLOCATE targetDbs_cur;


