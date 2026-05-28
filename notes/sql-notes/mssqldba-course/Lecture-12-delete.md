```
title: "Lecture 12: DELETE"
date: 2025-09-22
course: Microsoft SQL Server Database Administation Course
tags: [#sql-basics, #sql-queries, #sql-dml]
summary: The basics to DELETE.
```
# DELETE

The DELETE statement is used to remove data from Tables and is part of DML.

**The basic syntax:**
```
DELETE FROM tableName
WHERE <conditions>;
```

Sometimes it will be needed to remove data from a table based on data in another table. This can be achieved by using a subquery or join:
```
-- Subquery
DELETE FROM tableName
WHERE column1 IN (
    SELECT
        column1
    FROM  tableName
    WHERE column2 = value
)
```
```
-- JOIN
DELETE table1 
FROM table1 t1
INNER JOIN table2 t2 ON t1.column1 = t2.column1
WHERE t2.column <condition>;
```