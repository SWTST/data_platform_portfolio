```
title: "Lecture 18: Clustered and Nonclustered indexes and Index Design"
date: 2025-10-13
course: Microsoft SQL Server Database Administation Course
tags: [#sql-basics, #sql-queries, #db-design, #sql-performance]
summary: Clustered vs Nonclustered indexes and Index design considerations
```

# Clustered Index

A clustered index stores the actual data rows at the leaf level of the index, which means that the entire row of data associated with the primary key value would be stored in that leaf node.

An important characteristic of clustered indexes is that they can only be stored in ascending or descending order. Therefore a table can only have 1 Clustered index.

If a Clustered index is not defined on a table, the data will not be sorted.

# Non-clustered Index

Unlike a clustered index; non-clustered indexes do not store the entire row of data but only the values of the indexed columns and the pointer to the other values in the table. This means that the query engine must take another step to retrieve this data.

A row locators structure depends on where it points to. If pointed to a clustered table then the locator will point to the clustered index  using the value from the index to obtain the correct row. If pointed to a heap then it will point to the actual data row.

The basic syntax for creating indexes is below:
```
-- Non Clustered Index
CREATE INDEX index1 ON schema1.table1 (Column1)

-- Clustered Index
CREATE CLUSTERED INDEX index1 ON schema1.table1 (Column1)

-- Non Clustered Index w/ Unique Constraint and specifying order of indexed columns
CREATE UNIQUE INDEX index1 ON schema1.table1 (Column1 DESC, Column2 ASC)
```

## Index types based on configuration

- **Composite Index:** An index that includes more than one column. In SQL server you can include up to 16 columns in an index as long as the index doesn't exceed the 900-byte limit. Both NC and C Indexes can be composite.
- **Unique Index:** An index that ensures uniqueness of each value in indexed columns. If the index is a composite, the uniqueness is enforced across the columns as a whole, on the individual columns.
  - A unique index is automatically created when you define a primary key or unique constraint.
- **Primary Key:** When you define a primary key constraint on one or more columns, SQL Server automatically creates a unique, C index if a C index does not already exist on the table.
- **Unique:** When you define a unique constraint, SQL Server automatically creates a unique, NC index.
- **Covering Index:** A type of index that includes all the columns that are needed to process a particular query.

# Index design considerations

- They can take up significant disk space.
- Indexes are automatically updated when the data rows themselves are updates, which can lead to additional overhead.
- Indexes can be counterproductive on small tables as it may quicker for the query engine to execute a table scan than to read an index.
- Try to insert or modify as many rows as possible in a single statement, rather than using multiple queries.
- Aim to create NC indexes on columns that are frequently used in predicates and join conditions.