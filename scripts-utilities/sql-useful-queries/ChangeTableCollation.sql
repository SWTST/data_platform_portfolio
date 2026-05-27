-- Change column collation for whole table 

DECLARE @sql NVARCHAR(MAX);
DECLARE @colName SYSNAME;
DECLARE @dataType varchar(max);
DECLARE @length varchar(max);

DECLARE dbCursor CURSOR FOR
    SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'AHT_React4TenancyImportData'
	AND DATA_TYPE IN ('varchar','char'); -- Does not consider nvarchar, text, ntext
										 -- String does not concatenate with MAX
										 -- Use IF statement and CAST
OPEN dbCursor;
FETCH NEXT FROM dbCursor INTO @colName, @datatype, @length;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = 'ALTER TABLE [dbo].[AHT_React4TenancyImportData]
                ALTER COLUMN [' + @colName + '] '+@datatype +'('+@length+') COLLATE Latin1_General_CI_AS';
    PRINT @sql; -- For debugging
    EXEC(@sql);

    FETCH NEXT FROM dbCursor INTO @colName, @datatype, @length;
END

CLOSE dbCursor;
DEALLOCATE dbCursor;