```
title: "Lecture 06: WHERE, ORDER BY, HAVING, GROUP BY"
date: 2025-09-08
course: Microsoft SQL Server Database Administation Course
tags: [#sql-basics, #sql-queries]
summary: How clauses are used in SQL Queries
```

# WHERE, ORDER BY, HAVING BY, GROUP BY

### WHERE
WHERE is used to specify a condition when fetching data from a table or tables. Its not only used in SELECT but also in UPDATE and DELETE

### GROUP BY
GROUP BY is used in collaboration with the SELECT statement to arrange identical data into groups. They are used in conjunction with aggregate functions to group the result set by one or more columns.

### HAVING
HAVING enables you to specify conditions that filter which groups appear in your results

### ORDER BY
ORDER BY is used to sort the data in ascending or descending order, based on one or more columns.

**The correct order of use for these clauses is respective to this notes order**

## Query Examples

### WHERE - with all operator examples
```
USE AdventureWorks2022
go

select * from Person.address where postalcode = '98011'

select * from Person.address where postalcode != '98011'

select * from Person.address where postalcode <> '98011'

select count(*) from Person.address where postalcode <> '98011'

select * from Person.address where ModifiedDate >= '2013-11-08 00:00:00'

select * from Person.address where ModifiedDate <= '2013-11-08 00:00:00'

select * from Person.Person where FirstName like 'mat%'

select * from Person.Person where FirstName like '%ew'

select * from Person.Person where FirstName like '%EW'

select * from [HumanResources].[EmployeePayHistory]

select max(rate) from [HumanResources].[EmployeePayHistory]

select max(rate) AS MaxPayrate from [HumanResources].[EmployeePayHistory]

select min(rate) AS [Min Pay rate] from [HumanResources].[EmployeePayHistory]

select * from [Production].[ProductCostHistory] where startdate = '2013-05-30 00:00:00'

select * from [Production].[ProductCostHistory] where startdate = '2013-05-30 00:00:00' and StandardCost >= 200

select * from [Production].[ProductCostHistory] where( startdate = '2013-05-30 00:00:00' and StandardCost >= 200) or ProductID >800

select * from [Production].[ProductCostHistory] where( startdate = '2013-05-30 00:00:00' and StandardCost >= 200) and ProductID >800

select * from [Production].[ProductCostHistory] where ProductID in (802,803,820,900)

select * from [Production].[ProductCostHistory] where EndDate is null

select * from [Production].[ProductCostHistory] where EndDate is not null
```
### ORDER BY
```
USE AdventureWorks2022
go

select * from [HumanResources].[EmployeePayHistory] order by rate 

select * from [HumanResources].[EmployeePayHistory] order by rate asc

select * from [HumanResources].[EmployeePayHistory] order by rate desc


select * from [HumanResources].[EmployeePayHistory] where  ModifiedDate >= '2010-06-30 00:00:00' order by ModifiedDate desc

select * from [HumanResources].[EmployeePayHistory] where  year(ModifiedDate) >= '2014' order by ModifiedDate desc

select * from [HumanResources].[EmployeePayHistory] where  month(ModifiedDate) = '06' order by ModifiedDate desc
```
### GROUP BY
```
USE AdventureWorks2022
go

select * from Person.address where postalcode = '98011'

select count(*) from Person.address where postalcode = '98011'

select count(*),postalcode from Person.address group by PostalCode

select count(*) as NoOfAddresses,postalcode from Person.address group by PostalCode

select count(*) as NoOfAddresses,postalcode from Person.address group by PostalCode order by PostalCode

select count(*),City from Person.address group by City

select count(*),City,PostalCode from Person.address group by City,PostalCode
```
### HAVING
```
USE AdventureWorks2022
go

select * from Production.product

select count(*) countofproduct,Color from Production.product where color = 'yellow' group by Color

select count(*) countofproduct,Color from Production.product group by Color having Color = 'yellow'

select count(*) countofproduct,Color,Size from Production.product group by Color,size having Size >= '44'
```