```
title: "Lecture 10 & 11: Insert and Update"
date: 2025-09-22
course: Microsoft SQL Server Database Administation Course
tags: [#sql-basics, #sql-queries, #sql-dml]
summary: The basics to INSERT and UPDATE.
```

# INSERT and UPDATE

Below I will be investigating the basics to INSERT and UPDATE in SQL.

## INSERT

INSERT statements are used to add rows to a target table. These rows can be defined manually or defined from another table.

**The basic syntax:**
```
--Select columns
INSERT INTO tableName (Column1, Column2, Column3, ...)
VALUES (Value1, Value2, Value3, ...)
```
```
--All columns
INSERT INTO tableName
VALUES (Value1, Value2, Value3, ...)
```
Data can also be Inserted based off of a SELECT statement, like the below:
```
INSERT INTO TargetTable (Column1, Column2, ...)
SELECT Column1, Column2, ...
FROM SourceTable
WHERE <conditions>;
```
Finally, SELECT INTO can be used to copy data into a NEW table. If the table exists already then it will need to be dropped before the statement can run. The syntax is below:
```
SELECT Column1, Column2
INTO targetTable
FROM sourceTable
WHERE <conditions>;
```

## UPDATE

UPDATE statements are used to modify values within a table. The WHERE clause is typically used to define a condition but FROM/JOINs can also be used if sample data is needed for the UPDATE.

**The basic syntax:**
```
UPDATE tableName
SET 
column1 = value1,
column2 = value2,
...
WHERE <conditions>;
```
```
--Using another table for the data used in the UPDATE
UPDATE t
SET t.Column1 = s.Column1,
    t.Column2 = s.Column2
FROM TargetTable t
JOIN SourceTable s ON t.KeyColumn = s.KeyColumn
WHERE <optional conditions>;
```
