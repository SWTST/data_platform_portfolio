```
title: "Lecture 24: System Databases Do's and Dont's"
date: 2025-11-03
course: Microsoft SQL Server Database Administation Course
tags: [#sql-basics, #mssql-internals, #system-databases, #db-design, #sql-performance]
summary: Intro to System Databases
```

# Introductions to System Databases

System databases are created when SQL Server is installed. They are critical to SQL Servers operation. These databases keep meta data about the MSSQL Instance. If a system database is lost then SQL server will not operate. These databases collectively maintain and manage a lot of information about the SQL Server system like logins, database, linked servers, jobs, schedules, reports etc.

## MSSQL System Databases

- **Master** - Core system database to manage the SQL Server instance.
- **TempDB** - Database to store temporary tables,. table variables, cursors, work tables, row versioning, create or rebuild indexes sorted in TempDB.
- **MSDB** - Primary database to manage the SQL Server Agent configurations.
- **Resource** - The resource database is responsible for physically storing all of the SQL Server 2005 System objects.
- **Model** - Template database for all user defined databases.
- **Distribution** - Primary data to support SQL Server Replication.

### DO's and DONT's

- **Data access**: Based on the Version of SQL Server only the recommended objects
- **Changing Objects**: Do not change system objects.
- **New Objects**: Creating objects in the system databases is not recommended
- **Backups**: Ensure to have a consistent backup process for your system databases 