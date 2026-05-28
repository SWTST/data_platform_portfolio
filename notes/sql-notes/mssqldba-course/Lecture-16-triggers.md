```
title: "Lecture 16: What are triggers?"
date: 2025-10-06
course: Microsoft SQL Server Database Administation Course
tags: [#sql-basics, #sql-queries, #db-design]
summary: What are the basics to triggers and how are they used?
```

# Triggers

Triggers are special SPs that are executed automatically in response to the database object, database, and server events.

### Types of triggers:

- **DML Triggers:** which are invoked automatically in response to INSERT, UPDATE, and DELETED events against tables
- **DDL Triggers:** which are invoked in response to CREATE, ALTER, and DROP statements. These triggers also fire in response to some system stored procedures that perform DDL-like operations.
- **Logon Triggers:** fire in response to LOGON events.

The basic syntax to create a trigger is below:
```
CREATE TRIGGER [schemaName].[triggerName]
ON tableName
AFTER {[INSERT],[UPDATE],[DELETE]}
<[NOT FOR REPLICATION]>
AS
<sqlStatements>
```

The below are examples of how different types of triggers are used:
```
CREATE TRIGGER AfterInsertTrigger ON TriggerDemo_Parent
AFTER INSERT
AS 
INSERT INTO TriggerDemo_History 
VALUES ((SELECT TOP 1 ID FROM TriggerDemo_Parent), 'Insert')
GO

CREATE TRIGGER AfterDeleteTrigger ON TriggerDemo_Parent
AFTER DELETE
AS 
INSERT INTO TriggerDemo_History 
VALUES ((SELECT TOP 1 ID FROM TriggerDemo_Parent), 'Delete')
GO

CREATE TRIGGER AfterUPDATETrigger ON TriggerDemo_Parent
AFTER UPDATE
AS 
INSERT INTO TriggerDemo_History 
VALUES ((SELECT TOP 1 ID FROM TriggerDemo_Parent), 'UPDATE')
GO
```