-- Check last backup times

SELECT   d.name,
         d.recovery_model_desc,
         MAX(b.backup_finish_date) AS backup_finish_date
FROM     master.sys.databases d
         LEFT OUTER JOIN msdb..backupset b
         ON       b.database_name = d.name
         AND      b.type          = 'L'
GROUP BY d.name, d.recovery_model_desc
ORDER BY backup_finish_date DESC
