```
title: "Lecture 15: What is a Function?"
date: 2025-10-06
course: Microsoft SQL Server Database Administation Course
tags: [#sql-basics, #sql-queries, #db-design]
summary: What are the basics to functions and how are they used?
```

# Functions

Functions are used to perform specific tasks. Functions accept only input parameters and perform actions to return a result. The result can be a single value or a table.

We can't use a function to carry out DML statements directly.

Finally, SPs cannot be executed within SQL Statements where as functions can.

The basic syntax to create a function is below:
```
CREATE FUNCTION [DatabaseName].[FunctionName] (parameters)
RETURNS data_type as
BEGIN
<SQL statement(s)>
RETURN value
END
```

## Types of Functions

### Built-in Functions

- **Scalar Functions:** Scalar functions operate on a single value and return a single value.
  - upper('value')
  - lower('VALUE')
  - convert(int, value)
- **Aggregate Functions:** Aggregate functions operate on a collection of different values and return a single value.
  - max()
  - min()
  - avg()
  - count()
- **Date and Time Functions:** Related to Date and time.
  - GETDATE()
  - Datediff()
  - DateAdd()
  - Day()
  - Month()
  - Year()

### User-Defined Functions

- **Scalar Functions:** Similarly, this returns a single value based of actions performed in the function.
- **Inline Table-Values Function:** This function returns a table variable as a result of actions performed in the function.
- **Multi-Statement Table-Valued Function:** This function returns a table variable as a result of actions performed in the function. A table variable must be declared and defined with results from multiple SQL statements within the function.

## Differences between SPs and Functions

| Functions    | SPs  |
| -------- | ------- |
| Must return a Value  | Can be 0 or NULL |
| Can only have input parameters | Can have both Input and output parameters |
| Can be called in SPs | Cannot be called in Functions |
| Only allows SELECT | Allows all DML |
| Can be embedded in SELECT | Cannot be embedded in SELECT|
| Cannot use try-catch blocks | Can use try-catch blocks |
| Cannot use transactions | Can use transactions  |