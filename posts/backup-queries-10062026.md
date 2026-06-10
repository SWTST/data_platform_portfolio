# Backup Queries

## Summary

- What are the queries?
- What do they do?
- Why are they useful?

### Latest Backups

- This query finds the latest backups, of each type, for each database. The columns included int he final result of this query are database_name, backup_type, backup_finish_date, backup_age (numeric) and backup_age (readable).
- It derives all information from msdb.dbo.backupset and sys.databases. A CTE is used to find and group backup types and then another is used to find the latest of each. The backup_age is calculated with some simple arithmetic and then the results are ordered by database name and backup_type
- This query serves its purpose well; it is super simple and tells you exactly if your backups are happening as you think they are. The backup age is a nice inclusion and makes it even easier to understand if you have stale backups.

### Backup Size

- The second finds all backups held in msdb.dbo.backupset for a specific database. It then evaluates the Size, Compression and Duration of the backup.
- This query is simpler than the last and shares many similarities, we pull all information from msdb.dbo.backupset and miss out on the CTEs and JOIN. Using columns such as backup_size, compressed_backup_size, backup_start_date and backup_finish_date we then use simple arithmetic to calculate backup size in MB both raw and compressed, and also the find the Duration of the backup in minutes.
- This focuses more on the RPOs and RTOs of your databases outlining important factors that you need to know. Can I store my backup there? Can it be moved elsewhere? How long is it going to take to backup/restore?

### Post Draft

Your backup job succeeded. That doesn't mean you can restore.

"The job ran" and "I can actually recover" are two different claims, and the gap between them is where DBAs get caught out. I've put together four queries that bridge that gap, here's what each one catches.

Is it even happening? The first pulls the latest backup of each type, per database, with the age in plain English. Five seconds to confirm nothing's gone stale.

What am I silently missing? That first query only shows what you have. The dangerous case is what's absent, a database in FULL recovery with zero log backups. Unbounded log growth, no point-in-time recovery, and it won't appear in a "latest backups" list because there's nothing there to list. The second query hunts those down and flags them by name.

Can I actually restore the chain? The one that matters at 2am: LSN integrity. It walks the full + log sequence and checks each link genuinely joins to the next, no gaps or breaks. A pile of log backups that won't restore is just as bad as not taking them in the first place.

And the RTO math. A size/duration query. How big? How compressed? How long it runs? Exactly what you need when someone asks "how long until we're back?"

Job-succeeded monitoring tells you the backup happened. These tell you whether it's worth anything.

Queries are in the repo 👇

(https://github.com/SWTST/data_platform_portfolio/blob/main/scripts-utilities/sql-useful-queries/CheckBackupInfo.sql)