-- Check all stored procedures for Object references

USE [master]
GO

/****** Object:  StoredProcedure [dbo].[SHSP_ObjectRefCheck]    Script Date: 16/02/2026 16:32:31 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER PROCEDURE [dbo].[SHSP_ObjectRefCheck]
      @ObjectRef         VARCHAR(150),
      @IncludeDefinition bit = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('tempdb..#Results') IS NOT NULL
        DROP TABLE #Results;

    CREATE TABLE #Results
    (
          [Database] SYSNAME
        , ObjectName SYSNAME
        , TypeDesc   NVARCHAR(60)
        , ModifyDate DATETIME
        , ObjectId   INT
        , Definition NVARCHAR(MAX) NULL
    );

    DECLARE @sql NVARCHAR(MAX) = N'';

    ;WITH DBs AS (
        SELECT name
        FROM sys.databases
        WHERE database_id > 4
          AND state = 0
    )
    SELECT @sql = @sql + '
    INSERT INTO #Results ([Database], ObjectName, TypeDesc, ModifyDate, ObjectId, Definition)
    SELECT
          ''' + name + ''' AS [Database]
        , o.name
        , o.type_desc
        , o.modify_date
        , m.object_id
        ' + CASE WHEN @IncludeDefinition = 1
                 THEN ', m.definition'
                 ELSE ', NULL'
            END + '
    FROM ' + QUOTENAME(name) + '.sys.sql_modules m
    INNER JOIN ' + QUOTENAME(name) + '.sys.objects o
        ON m.object_id = o.object_id
    WHERE o.type IN (''P'', ''V'', ''FN'', ''IF'', ''TF'')
      AND m.definition LIKE ''%'' + @ObjectRef + ''%'';
    '
    FROM DBs;

    EXEC sp_executesql
          @sql
        , N'@ObjectRef VARCHAR(150)'
        , @ObjectRef = @ObjectRef;

    SELECT *
    FROM #Results
    ORDER BY [Database], ObjectName;
END
GO

ALTER AUTHORIZATION ON [dbo].[SHSP_ObjectRefCheck] TO  SCHEMA OWNER 
GO