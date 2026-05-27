```
title: "Query Tuning Fundamentals 1"
date: 2025-10-03
tags: [#sql-queries, #sql-dml, #sql-ddl, #sql-performance]
summary: Building on my Fundamentals to query optimisation
```

# Query Tuning Fundamentals

The query optimizer transforms a parsed query into an execution plan and picks a plan with minimal estimated cost. Exploring all possible plans is combinatorically expensive, optimizers use heuristics, cost models, pruning, and time limits — so the “optimal” plan discovered is often a near-optimal one. 

Key levers for you (the “tuner”) are: 

- Rewriting SQL (logical rewrites) 
- Creating or adjusting indexes 
- Updating statistics 
- Partitioning 
- Hints (if available) 
- Changing schema / data layout.

**The common phases of query execution are as follows:**
1. Parsing / validation
2. Logical plan generation / rewriting (algebraic transformations, pushing filters, flattening subqueries)
3. Physical plan selection (choosing which join algorithms, index scans vs table scans, sorting strategies)
4. Execution (materialization, pipelining, memory / spill usage)

## Query Optimisation Guides and Documentation:

- **Using the SQL Execution Plan for Query Performance Tuning**— shows how to read a plan, identify expensive operators, follow arrows, spot scans vs seeks, etc.
  
- **SQL Query Optimization: 15 Techniques for Better Performance** — gives a nice checklist of common techniques and pitfalls. 
  
- **Mode’s “Performance Tuning SQL Queries”** - a gentle top-down refresher.