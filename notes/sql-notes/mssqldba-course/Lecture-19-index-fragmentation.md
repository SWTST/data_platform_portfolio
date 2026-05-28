```
title: "Lecture 19: Index Fragmentation"
date: 2025-10-13
course: Microsoft SQL Server Database Administation Course
tags: [#sql-queries, #db-design, #sql-performance]
summary: What is Index Fragmentation? How does it affect performance?
```

# Index Fragmentation

SQL Server Index fragmentation is a common source of database performance degradation.

Fragmentation occurs when either:
- There is a large amount of empty space on a data page (Internal Fragmentation)
- When there is a logical order to the indexed pages that does not match the physical order of pages in a data file (external fragmentation)

## Internal Index fragmentation

Internal index fragmentation occurs when there is too much free space on a data page. The extra space is introduced through a few different avenues:
- SQL server stores data on 8KB pages. So when you insert less than 8KB of data into a table, you're left with blank space on a page.
- If you insert more data than the page has space for, the excess is sent to another page. It's unlikely that the additional data will perfectly fill the subsequent pages. This leaves you with empty space.
- Blank space can also be created by delete statement when data is removed from a table.


## External Index fragmentation

External fragmentation is a results of data pages being out of order.

This is causes by inserting or updating data to full leaf pages. When data is added to a full page SQL Server creates a page split to accommodate for the extra data. The new page is separated from the original page.

When pages are not sequential, SQL server has to read data from multiple sources which slows performance when compared to reading data which is ordered.

## Fix SQL Server Index Fragmentation

The best place to start using the sys.dm_db_index_physical_stats which helps to analyse the level of fragmentation of your indexes. Once understood how extensive index fragmentation is there are 3 options:

- **Rebuild:** Rebuild indexes when fragmentation reaches greater than 30 percent.
- **Reorganise:** Reorganise indexes with between 11-30 percent fragmentation.
- **Ignore:** Fragmentation levels of 10 percent or below should not pose a performance problem.
