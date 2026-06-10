
-- Latest of each backup

DECLARE @Now datetime = GETDATE();

;WITH backup_cte AS
(
    SELECT
        bs.database_name,
        backup_type =
            CASE bs.type
                WHEN 'D' THEN 'FULL'
                WHEN 'L' THEN 'LOG'
                WHEN 'I' THEN 'DIFF'
                ELSE 'Other'
            END,
        bs.backup_finish_date,
        rownum =
            ROW_NUMBER() OVER
            (
                PARTITION BY bs.database_name, bs.type
                ORDER BY bs.backup_finish_date DESC
            )
    FROM msdb.dbo.backupset bs
    INNER JOIN sys.databases d
        ON d.name = bs.database_name
    WHERE d.database_id > 4
      AND bs.type IN ('D','L','I')
),
latest_backups AS
(
    SELECT
        database_name,
        backup_type,
        backup_finish_date,
        AgeMinutes = DATEDIFF(MINUTE, backup_finish_date, @Now)
    FROM backup_cte
    WHERE rownum = 1
)
SELECT
    database_name,
    backup_type,
    backup_finish_date,
    AgeMinutes,
    BackupAge =
        CONCAT(
            AgeMinutes / 1440, ' Days ',
            (AgeMinutes % 1440) / 60, ' Hrs ',
            AgeMinutes % 60, ' Mins'
        )
FROM latest_backups
ORDER BY
    database_name,
    CASE backup_type
        WHEN 'FULL' THEN 1
        WHEN 'DIFF' THEN 2
        WHEN 'LOG'  THEN 3
        ELSE 4
    END;


-- Check Backup Size

DECLARE @BackupType char(1);
DECLARE @DBName sysname;

SET @DBName = 'DBA';
SET @BackupType = 'D';   -- D = Full, I = Diff, L = Log

SELECT
    bs.database_name,
    BackupType =
        CASE bs.type
            WHEN 'D' THEN 'FULL'
            WHEN 'I' THEN 'DIFF'
            WHEN 'L' THEN 'LOG'
            ELSE bs.type
        END,
    BackupSizeMB = CAST(bs.backup_size / 1048576.0 AS decimal(18,2)),
    CompressedBackupSizeMB = CAST(bs.compressed_backup_size / 1048576.0 AS decimal(18,2)),
    CompressionRatio =
        CASE
            WHEN bs.compressed_backup_size > 0
                THEN CAST(bs.backup_size * 1.0 / bs.compressed_backup_size AS decimal(18,2))
            ELSE NULL
        END,
    BackupStartDate = bs.backup_start_date,
    BackupFinishDate = bs.backup_finish_date,
    DurationMinutes = DATEDIFF(MINUTE, bs.backup_start_date, bs.backup_finish_date)
FROM msdb.dbo.backupset bs
WHERE bs.type = @BackupType
  AND bs.database_name = @DBName
ORDER BY bs.backup_finish_date DESC;


-- Full Recovery mode with no logs
DECLARE @Now datetime = GETDATE();

;WITH LatestLogBackup AS
(
    SELECT
        b.database_name,
        b.backup_finish_date,
        rn = ROW_NUMBER() OVER
        (
            PARTITION BY b.database_name
            ORDER BY b.backup_finish_date DESC
        )
    FROM msdb.dbo.backupset b
    WHERE b.type = 'L'
)
SELECT
    d.name AS DatabaseName,
    d.recovery_model_desc AS RecoveryModel,
    BackupType = 'LOG',
    BackupFinishDate = llb.backup_finish_date,
    AgeMinutes =
        CASE
            WHEN llb.backup_finish_date IS NULL THEN NULL
            ELSE DATEDIFF(MINUTE, llb.backup_finish_date, @Now)
        END,
    BackupAge =
        CASE
            WHEN llb.backup_finish_date IS NULL THEN 'No log backup found'
            ELSE CONCAT(
                    DATEDIFF(MINUTE, llb.backup_finish_date, @Now) / 1440, ' Days ',
                    (DATEDIFF(MINUTE, llb.backup_finish_date, @Now) % 1440) / 60, ' Hrs ',
                    DATEDIFF(MINUTE, llb.backup_finish_date, @Now) % 60, ' Mins'
                 )
        END
FROM sys.databases d
LEFT JOIN LatestLogBackup llb
    ON d.name = llb.database_name
   AND llb.rn = 1
WHERE d.database_id > 4
  AND d.recovery_model_desc = 'FULL'
ORDER BY d.name;

-- LSN Integrity

DECLARE @DatabaseName sysname = 'WorkflowDB';

;WITH LatestFull AS
(
    SELECT TOP (1)
        b.server_name,
        b.database_name,
        b.type,
        b.backup_finish_date,
        b.first_lsn,
        b.checkpoint_lsn,
        b.last_lsn,
        b.database_backup_lsn
    FROM msdb.dbo.backupset b
    WHERE b.database_name = @DatabaseName
      AND b.type = 'D'
    ORDER BY b.backup_finish_date DESC
),
FullAndLogs AS
(
    -- Base FULL backup row
    SELECT
        f.server_name,
        f.database_name,
        f.type,
        f.backup_finish_date,
        f.first_lsn,
        f.checkpoint_lsn,
        f.last_lsn,
        f.database_backup_lsn
    FROM LatestFull f

    UNION ALL

    -- LOG backups taken after that FULL
    SELECT
        l.server_name,
        l.database_name,
        l.type,
        l.backup_finish_date,
        l.first_lsn,
        l.checkpoint_lsn,
        l.last_lsn,
        l.database_backup_lsn
    FROM msdb.dbo.backupset l
    INNER JOIN LatestFull f
        ON f.server_name = l.server_name
       AND f.database_name = l.database_name
    WHERE l.type = 'L'
      AND l.backup_finish_date > f.backup_finish_date
),
OrderedChain AS
(
    SELECT
        fl.server_name,
        fl.database_name,
        fl.type,
        fl.backup_finish_date,
        fl.first_lsn,
        fl.checkpoint_lsn,
        fl.last_lsn,
        fl.database_backup_lsn,

        PrevType =
            LAG(fl.type) OVER
            (
                PARTITION BY fl.server_name, fl.database_name
                ORDER BY fl.backup_finish_date,
                         CASE fl.type WHEN 'D' THEN 1 WHEN 'L' THEN 2 ELSE 3 END
            ),

        PrevBackupFinishDate =
            LAG(fl.backup_finish_date) OVER
            (
                PARTITION BY fl.server_name, fl.database_name
                ORDER BY fl.backup_finish_date,
                         CASE fl.type WHEN 'D' THEN 1 WHEN 'L' THEN 2 ELSE 3 END
            ),

        PrevLastLSN =
            LAG(fl.last_lsn) OVER
            (
                PARTITION BY fl.server_name, fl.database_name
                ORDER BY fl.backup_finish_date,
                         CASE fl.type WHEN 'D' THEN 1 WHEN 'L' THEN 2 ELSE 3 END
            ),

        BaseFullBackupFinishDate =
            MAX(CASE WHEN fl.type = 'D' THEN fl.backup_finish_date END) OVER
            (
                PARTITION BY fl.server_name, fl.database_name
            ),

        BaseFullDatabaseBackupLSN =
            MAX(CASE WHEN fl.type = 'D' THEN fl.database_backup_lsn END) OVER
            (
                PARTITION BY fl.server_name, fl.database_name
            )
    FROM FullAndLogs fl
)
SELECT
    server_name,
    database_name,
    BackupType =
        CASE type
            WHEN 'D' THEN 'FULL'
            WHEN 'L' THEN 'LOG'
        END,
    backup_finish_date,
    first_lsn,
    checkpoint_lsn,
    last_lsn,
    database_backup_lsn,
    BaseFullBackupFinishDate,
    BaseFullDatabaseBackupLSN,
    PreviousBackupType =
        CASE PrevType
            WHEN 'D' THEN 'FULL'
            WHEN 'L' THEN 'LOG'
            ELSE NULL
        END,
    PrevBackupFinishDate,
    PrevLastLSN,
    ValidationStatus =
        CASE
            WHEN type = 'D' THEN 'BASE_FULL'

            WHEN type = 'L'
                 AND PrevType = 'D'
                 AND database_backup_lsn = BaseFullDatabaseBackupLSN
                THEN 'FIRST_LOG_AFTER_FULL_OK'

            WHEN type = 'L'
                 AND PrevType = 'D'
                 AND database_backup_lsn <> BaseFullDatabaseBackupLSN
                THEN 'FIRST_LOG_AFTER_FULL_DB_BACKUP_LSN_MISMATCH'

            WHEN type = 'L'
                 AND PrevType = 'L'
                 AND PrevLastLSN = first_lsn
                THEN 'LOG_CHAIN_CONTIGUOUS'

            WHEN type = 'L'
                 AND PrevType = 'L'
                 AND PrevLastLSN <> first_lsn
                THEN 'LOG_CHAIN_GAP_OR_BREAK'

            ELSE 'CHECK_REQUIRED'
        END,
    Notes =
        CASE
            WHEN type = 'D'
                THEN 'Restore base full backup'
            WHEN type = 'L' AND PrevType = 'D'
                THEN 'First log after full - validate with database_backup_lsn'
            WHEN type = 'L' AND PrevType = 'L'
                THEN 'Compare previous log last_lsn to current log first_lsn'
            ELSE NULL
        END
FROM OrderedChain
ORDER BY backup_finish_date,
         CASE type WHEN 'D' THEN 1 WHEN 'L' THEN 2 ELSE 3 END;