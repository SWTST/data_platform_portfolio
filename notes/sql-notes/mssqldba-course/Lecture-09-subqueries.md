```
title: "Lecture 09: Subqueries"
date: 2025-09-16
course: Microsoft SQL Server Database Administation Course
tags: [#sql-basics, #sql-queries, #sql-performance]
summary: What are Subqueries and how are they used?
```

# Subqueries

Subqueries are "inner queries" that are used to restrict data retrieval further and can be used in SELECT, INSERT, UPDATE, DELETE statements, along with operators. They can be used to retrieve a scalar value or a rowset. 

### **Subquery Rules:**

- Subqueries must be enclosed in parentheses.
- A Subquery can only have one column in the SELECT clause, unless multiple columns are in the main query for the subquery to compare its selected columns.
- An ORDER BY command cannot be used in a Subquery.
- Subqueries that return more than one row can only be used with multiple value operators such as IN.
- The BETWEEN operator cannot be used within a Subquery.

## Basic Syntax
```
SELECT
    Column1,
    Column2,
    ...
FROM Table1
WHERE value IN (SELECT Column1 FROM table2 WHERE condition)
```

## Subquery Examples 
```
-- SELECT all pay History for each ID that has ever had a rate higher than 60 
SELECT *
FROM [HumanResources].[EmployeePayHistory]
WHERE [BusinessEntityID] IN ( SELECT [BusinessEntityID] FROM [HumanResources].[EmployeePayHistory] WHERE Rate > 60)
```
```
-- SELECT all pay history for the ID that has ever had a rate equal to 39.06
SELECT *
FROM [HumanResources].[EmployeePayHistory]
WHERE [BusinessEntityID] = ( SELECT [BusinessEntityID] FROM [HumanResources].[EmployeePayHistory] WHERE Rate = 39.06)
```
```
-- SELECT all information about products FROM [Product] that have a quantity greater than 300 IN [ProductInventory]
SELECT *
FROM [Production].[Product]
WHERE [ProductID] IN (SELECT [ProductID] FROM [Production].[ProductInventory] WHERE Quantity > 300)
```