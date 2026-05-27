-- Update Job info dynamically based on dbo.sysjobs 

DECLARE @name VARCHAR(200)

DECLARE db_cursor CURSOR FOR 
SELECT name 
FROM msdb.dbo.sysjobs
OPEN db_cursor  
FETCH NEXT FROM db_cursor INTO @name  
WHILE @@FETCH_STATUS = 0  
BEGIN  
      EXEC msdb.dbo.sp_update_job 
	 @job_name = @name,
	 @notify_level_email = 2,
	@notify_email_operator_name = N'DBA Team',
	@notify_page_operator_name = N'';
--comment out following line to disable netsend
--, @notify_netsend_operator_name = N''
--comment out following line to disable writing entry into Windows application log
--, @notify_level_eventlog = 0
      FETCH NEXT FROM db_cursor INTO @name 
END 
CLOSE db_cursor  
DEALLOCATE db_cursor;