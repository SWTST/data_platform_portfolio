```
title: "Lecture 14: What is a Stored Procedure?"
date: 2025-09-29
course: Microsoft SQL Server Database Administation Course
tags: [#sql-basics, #sql-queries, #db-design]
summary: What are the basics to SPs and how are they used?
```

# Stored Procedures

Stored procedures are batches of SQL statements that can be reused and re-executed to produce a result set or complete a function. They accept defined parameters which are used within the procedure.

## Advantages to using SPs

- **Better Performance:** The procedure calls are quick and efficient as SPs are compiled once and stored in executable form. The executable code is automatically cached and therefore lowers the memory requirements. I.e. A plan is created initially for the SP and saved to memory so that it will be reused if the SP is run again.
- **Reusable:** The procedure can be easily used by other users or applications without having to replicate code
- **Security:** SPs reduce Security threat by eliminating the need for direct access to tables. SPs can also be encrypted so the source code is not visible.

The basic syntax for SPs is below:
```
-- Creating a SP
CREATE PROCEDURE ProcedureName
AS 
<sql_statement>
GO;

-- Executing a SP
EXEC ProcedureName;

-- Creating a SP with undefined Parameter(s)
CREATE PROCEDURE ProcedureName (@Parameter1 VARCHAR(15))
AS 
SELECT *
FROM TableName
WHERE Column1 > @Parameter1
GO;

-- Creating a SP with defined parameter(s)
CREATE PROCEDURE ProcedureName (@Parameter1 VARCHAR(15) = 'Value')
AS 
SELECT *
FROM TableName
WHERE Column1 > @Parameter1
GO;
```

You can also use **WITH ENCRYPTION** to encrypt the SP source code. The syntax is below:
```
CREATE PROCEDURE ProcedureName
WITH ENCRYPTION
AS 
<sql_statement>
GO;
```