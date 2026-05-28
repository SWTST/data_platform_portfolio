```
title: "Lecture 20, 21 & 22: Overview of MSSQL Management Tools"
date: 2025-10-27
course: Microsoft SQL Server Database Administation Course
tags: [#sql-basics, #mssql-internals, #mssql-management-tools, #db-design, #sql-performance]
summary: An Overview of MSSQL Management tools and how they are used
```

# Overview of MSSQL Management Tools

- **SQL Server Management Studio (SSMS):** is an integrated environment to access, configure, manage, administer and develop components of SQL Servers.

- **SQL Server configuration manager:** SQL Server configuration manager provides basic configuration management for SQL Server services, Server protocols, Client protocols and client Aliases

- **SQL Server Profiler:** SQL Server Profiler provides a graphical user interface to monitor an instance of the database engine or Analysis Services.

- **Database Engine Tuning Advisor:** Database Engine tuning Advisor helps create optimal sets of indexes, indexed views and partitions.

- **SQL Server Data Tools:** SQL Server Data Tools provides an IDE forBuilding solutions for Business Intelligence components: Analysis Services, Reporting Services and Integration Services.


## SQL Server Management Studio (SSMS)

SSMS is a generalised management platform for all kinds of SQL related work.

Some utilisations of SSMS are:

- Connecting to a local/remote SQL Server database engine, SSIS, SSRS and Analysis Services
- Explore Server properties and its objects
- Explore Databases and its objects.
- New Query / Query Parsing / Execution / Results and Execution plans.
- Monitor SQL server using Activity Monitor / sp_who2 & sp_whoisactive / SQL Logs
- DBA Admin tasks (Backup / Logins / Jobs / Maintenance plans)

**Execution plans**

You can view execution plans for queries by enabling them via the 'include actual execution plan' button in SSMS when running a query. You can then optimise your query using this plan. Another option is the 'estimated execution plan' which generates a plan without running the query.


Also, with 'View > Object explorer details' You can see table level information like 'data used' and 'Row count' in a spreadsheet-style format. 



