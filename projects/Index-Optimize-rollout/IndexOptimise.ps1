#=========================================================================
# IndexOptimise.ps1 - Phase 1 IndexOptimize rollout (Ola Hallengren)
#
# Single-file, phase-driven script. Does NOT touch DatabaseBackup jobs
# under any circumstances (brief §3, §5). DBCC is Phase 2 and not in scope.
#
# Phases:
#   Discover        read-only inventory -> DBA.dbo.tblIndexOptimizeRollout
#   InstallPrereqs  installs Ola framework (CommandExecute, CommandLog,
#                   IndexOptimize) only. No jobs are created here.
#   Deploy          builds parameters from legacy mapping (tblDatabaseConfig
#                   + job-step flags) or defaults, creates new job disabled,
#                   audits every setting.
#   Cutover         atomically: disable legacy, enable new. Legacy is retained
#                   disabled for 30 days (brief §11).
#=========================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ServerName,
    [Parameter(Mandatory)][ValidateSet('Discover', 'InstallPrereqs', 'Deploy', 'Cutover')][string]$Phase,
    [int]$TimeLimitSeconds = 25200,
    [System.Management.Automation.PSCredential]$SsaCredential,
    [System.Management.Automation.PSCredential]$WindowsCredential
)

Set-DbatoolsConfig -FullName sql.connection.trustcert -Value $true -Register | Out-Null

# --------------------------------------------------------------------
# Constants
# --------------------------------------------------------------------
$NewJobName = '(DBA) - IndexOptimise - USER_DATABASES'
$LegacyJobName = '(DBA) - Optimisation'

# Documented defaults (brief §8)
$DefaultOlaParams = [ordered]@{
    Databases              = 'USER_DATABASES'
    FragmentationLevel1    = 5
    FragmentationLevel2    = 30
    FragmentationLow       = $null
    FragmentationMedium    = 'INDEX_REORGANIZE,INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'
    FragmentationHigh      = 'INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE,INDEX_REORGANIZE'
    MinNumberOfPages       = 1000
    MaxNumberOfPages       = $null
    UpdateStatistics       = 'ALL'
    OnlyModifiedStatistics = 'Y'
    LogToTable             = 'Y'
    TimeLimit              = $TimeLimitSeconds
}

# Fallback schedule (22:00 daily) if no legacy schedule is present
$DefaultSchedule = @{
    Name                   = '(DBA) - IndexOptimise Nightly'
    Enabled                = 1
    Freq_Type              = 4     # Daily
    Freq_Interval          = 1     # Every day
    Freq_Subday_Type       = 1     # At the specified time
    Freq_Subday_Interval   = 0
    Freq_Relative_Interval = 0
    Freq_Recurrence_Factor = 0
    Active_Start_Date      = (Get-Date -Format 'yyyyMMdd')
    Active_End_Date        = 99991231
    Active_Start_Time      = 220000
    Active_End_Time        = 235959
}

$RunId = [guid]::NewGuid()
$RunTs = Get-Date

# --------------------------------------------------------------------
# Credentials (prompt only if not supplied)
# --------------------------------------------------------------------
if (-not $SsaCredential) { $SsaCredential = Get-Credential -Message 'Enter SSA login' }
if (-not $WindowsCredential) { $WindowsCredential = Get-Credential -Message 'Enter Windows login' }

function Get-ResolvedCredential {
    param([string]$SqlInstance)
    try {
        $null = Invoke-DbaQuery -SqlInstance $SqlInstance -SqlCredential $SsaCredential -Query 'SELECT 1' -EnableException
        return $SsaCredential
    }
    catch {
        return $WindowsCredential
    }
}

function Invoke-Sql {
    param(
        [string]$SqlInstance,
        [System.Management.Automation.PSCredential]$Credential,
        [string]$Query,
        [string]$Database
    )
    $splat = @{
        SqlInstance     = $SqlInstance
        SqlCredential   = $Credential
        Query           = $Query
        EnableException = $true
    }
    if ($Database) { $splat.Database = $Database }
    return Invoke-DbaQuery @splat
}

# --------------------------------------------------------------------
# Audit table
# --------------------------------------------------------------------
function Ensure-AuditTable {
    param([string]$SqlInstance, [System.Management.Automation.PSCredential]$Credential)
    Invoke-Sql -SqlInstance $SqlInstance -Credential $Credential -Query @"
IF DB_ID('DBA') IS NULL CREATE DATABASE DBA;
"@

    Invoke-Sql -SqlInstance $SqlInstance -Credential $Credential -Database DBA -Query @"
IF OBJECT_ID('dbo.tblIndexOptimizeRollout','U') IS NULL
    CREATE TABLE dbo.tblIndexOptimizeRollout
    (
        RecordId     BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        RunId        UNIQUEIDENTIFIER NOT NULL,
        RunTimestamp DATETIME2        NOT NULL,
        Phase        NVARCHAR(30)     NOT NULL,
        ServerName   SYSNAME          NOT NULL,
        Finding      NVARCHAR(200)    NOT NULL,
        FindingValue NVARCHAR(MAX)    NULL,
        Source       NVARCHAR(20)     NULL,
        Notes        NVARCHAR(MAX)    NULL
    );
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_tblIndexOptimizeRollout_RunId')
    CREATE INDEX IX_tblIndexOptimizeRollout_RunId ON dbo.tblIndexOptimizeRollout(RunId);
"@
}

function SqlLit {
    param($Value)
    if ($null -eq $Value) { return 'NULL' }
    return "N'" + ($Value.ToString() -replace "'", "''") + "'"
}

function Write-Audit {
    param(
        [string]$SqlInstance,
        [System.Management.Automation.PSCredential]$Credential,
        [string]$Finding,
        $FindingValue = $null,
        [string]$Source = $null,
        [string]$Notes = $null
    )
    $sql = @"
INSERT INTO DBA.dbo.tblIndexOptimizeRollout
  (RunId, RunTimestamp, Phase, ServerName, Finding, FindingValue, Source, Notes)
VALUES
  ('$RunId',
   '$($RunTs.ToString("yyyy-MM-dd HH:mm:ss"))',
   $(SqlLit $Phase),
   $(SqlLit $SqlInstance),
   $(SqlLit $Finding),
   $(SqlLit $FindingValue),
   $(SqlLit $Source),
   $(SqlLit $Notes));
"@
    Invoke-Sql -SqlInstance $SqlInstance -Credential $Credential -Query $sql
}

# --------------------------------------------------------------------
# Discovery queries
# --------------------------------------------------------------------
function Get-OlaState {
    param([string]$SqlInstance, [System.Management.Automation.PSCredential]$Credential)
    $sql = @"
IF DB_ID('DBA') IS NULL
    SELECT 0 AS HasCommandExecute, 0 AS HasCommandLog, 0 AS HasIndexOptimize, 0 AS HasNewJob
ELSE
    SELECT
        CASE WHEN OBJECT_ID('DBA.dbo.CommandExecute','P') IS NOT NULL THEN 1 ELSE 0 END AS HasCommandExecute,
        CASE WHEN OBJECT_ID('DBA.dbo.CommandLog','U')     IS NOT NULL THEN 1 ELSE 0 END AS HasCommandLog,
        CASE WHEN OBJECT_ID('DBA.dbo.IndexOptimize','P')  IS NOT NULL THEN 1 ELSE 0 END AS HasIndexOptimize,
        CASE WHEN EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'$NewJobName') THEN 1 ELSE 0 END AS HasNewJob;
"@
    return Invoke-Sql -SqlInstance $SqlInstance -Credential $Credential -Query $sql
}

function Get-JobSteps {
    param([string]$SqlInstance, [System.Management.Automation.PSCredential]$Credential, [string]$JobName)
    $sql = @"
USE msdb;
SELECT
    j.name              AS JobName,
    j.enabled           AS JobEnabled,
    j.description       AS JobDescription,
    SUSER_SNAME(j.owner_sid) AS JobOwner,
    c.name              AS JobCategory,
    js.step_id          AS StepId,
    js.step_name        AS StepName,
    js.subsystem        AS SubSystem,
    js.database_name    AS DatabaseName,
    js.command          AS StepCommand,
    js.output_file_name AS OutputFile,
    js.on_success_action AS OnSuccessAction,
    js.on_success_step_id AS OnSuccessStepId,
    js.on_fail_action   AS OnFailAction,
    js.on_fail_step_id  AS OnFailStepId,
    js.retry_attempts   AS RetryAttempts,
    js.retry_interval   AS RetryInterval,
    js.flags            AS Flags
FROM dbo.sysjobs j
JOIN dbo.sysjobsteps js ON j.job_id = js.job_id
LEFT JOIN dbo.syscategories c ON j.category_id = c.category_id
WHERE j.name = N'$($JobName -replace "'","''")'
ORDER BY js.step_id;
"@
    return Invoke-Sql -SqlInstance $SqlInstance -Credential $Credential -Query $sql
}

function Get-JobSchedules {
    param([string]$SqlInstance, [System.Management.Automation.PSCredential]$Credential, [string]$JobName)
    $sql = @"
USE msdb;
SELECT
    s.name, s.enabled, s.freq_type, s.freq_interval,
    s.freq_subday_type, s.freq_subday_interval,
    s.freq_relative_interval, s.freq_recurrence_factor,
    s.active_start_date, s.active_start_time,
    s.active_end_date,   s.active_end_time
FROM dbo.sysjobs j
JOIN dbo.sysjobschedules js ON j.job_id      = js.job_id
JOIN dbo.sysschedules   s  ON js.schedule_id = s.schedule_id
WHERE j.name = N'$($JobName -replace "'","''")'
ORDER BY s.schedule_id;
"@
    return Invoke-Sql -SqlInstance $SqlInstance -Credential $Credential -Query $sql
}

function Get-LegacyConfig {
    param([string]$SqlInstance, [System.Management.Automation.PSCredential]$Credential)
    # Returns $null if DBA or the config table is absent. Returns ALL rows
    # (not just mapped ones) so Discover can surface unknowns for review.
    $check = @"
SELECT CASE
    WHEN DB_ID('DBA') IS NULL THEN 0
    WHEN OBJECT_ID('DBA.dbo.tblDatabaseConfig','U') IS NULL THEN 0
    ELSE 1
END AS TableExists;
"@
    $exists = (Invoke-Sql -SqlInstance $SqlInstance -Credential $Credential -Query $check).TableExists
    if (-not $exists) { return $null }

    $sql = @"
USE DBA;
SELECT ConfigName, DatabaseName, CAST(DatabaseConfigValue AS NVARCHAR(100)) AS DatabaseConfigValue
FROM dbo.tblDatabaseConfig;
"@
    return , (Invoke-Sql -SqlInstance $SqlInstance -Credential $Credential -Query $sql)
}

# ConfigName values that Build-OlaParams knows how to map. Anything outside
# this set is surfaced in Discover as an unmapped unknown.
$KnownConfigNames = @(
    'REORGANIZE THRESHOLD',
    'REBUILD THRESHOLD',
    'REINDEX PAGES LOWER THRESHOLD',
    'REINDEX PAGES UPPER THRESHOLD',
    'REBUILD ONLINE',
    'INDEX STATS SCANMODE',
    'OPTIMISE EXCLUDE',
    'STATS EXCLUDE'
)

function Parse-LegacyStepParams {
    # The legacy step text contains a literal EXEC call with @Param = value pairs.
    # Values are either integers, NULL, or single-quoted strings (with '' escaping).
    param([string]$Command)
    $params = @{}
    $rx = [regex]"@(\w+)\s*=\s*('(?:[^']|'')*'|NULL|-?\d+)"
    foreach ($m in $rx.Matches($Command)) {
        $k = $m.Groups[1].Value
        $v = $m.Groups[2].Value
        if ($v -eq 'NULL') { $v = $null }
        elseif ($v -match '^-?\d+$') { $v = [int]$v }
        else { $v = $v.Substring(1, $v.Length - 2) -replace "''", "'" }
        $params[$k] = $v
    }
    return $params
}

# --------------------------------------------------------------------
# Mapping: legacy -> Ola IndexOptimize parameters
# --------------------------------------------------------------------
function Build-OlaParams {
    param($LegacyJobSteps, $LegacyConfigRows)

    $ola = [ordered]@{}
    foreach ($k in $DefaultOlaParams.Keys) {
        $ola[$k] = @{ Value = $DefaultOlaParams[$k]; Source = 'Default'; Notes = $null }
    }

    # --- tblDatabaseConfig (real thresholds at legacy runtime) ---
    if ($null -ne $LegacyConfigRows) {
        foreach ($row in $LegacyConfigRows) {
            switch ($row.ConfigName) {
                'REORGANIZE THRESHOLD' {
                    $ola.FragmentationLevel1 = @{
                        Value = [int]$row.DatabaseConfigValue; Source = 'Legacy'
                        Notes = 'tblDatabaseConfig.REORGANIZE THRESHOLD'
                    }
                }
                'REBUILD THRESHOLD' {
                    $ola.FragmentationLevel2 = @{
                        Value = [int]$row.DatabaseConfigValue; Source = 'Legacy'
                        Notes = 'tblDatabaseConfig.REBUILD THRESHOLD'
                    }
                }
                'REINDEX PAGES LOWER THRESHOLD' {
                    $ola.MinNumberOfPages = @{
                        Value = [int]$row.DatabaseConfigValue; Source = 'Legacy'
                        Notes = 'tblDatabaseConfig.REINDEX PAGES LOWER THRESHOLD'
                    }
                }
                'REINDEX PAGES UPPER THRESHOLD' {
                    # INT32 MAX (2147483647) means "no upper limit" in legacy, which
                    # matches Ola's NULL default. Still tag as Legacy-sourced so the
                    # review flag does not fire on an intentionally-unbounded upper.
                    $upper = [int64]$row.DatabaseConfigValue
                    if ($upper -ge 2147483647) {
                        $ola.MaxNumberOfPages = @{
                            Value  = $null; Source = 'Legacy'
                            Notes  = 'REINDEX PAGES UPPER THRESHOLD = INT32 MAX (no upper cap) - leaves @MaxNumberOfPages NULL'
                        }
                    }
                    else {
                        $ola.MaxNumberOfPages = @{
                            Value = [int]$upper; Source = 'Legacy'
                            Notes = 'tblDatabaseConfig.REINDEX PAGES UPPER THRESHOLD'
                        }
                    }
                }
                'REBUILD ONLINE' {
                    if ($row.DatabaseConfigValue -eq '0') {
                        $ola.FragmentationHigh = @{
                            Value = 'INDEX_REBUILD_OFFLINE'; Source = 'Legacy'
                            Notes = 'REBUILD ONLINE=0 disables online rebuilds'
                        }
                        $ola.FragmentationMedium = @{
                            Value = 'INDEX_REORGANIZE,INDEX_REBUILD_OFFLINE'; Source = 'Legacy'
                            Notes = 'REBUILD ONLINE=0 disables online rebuilds'
                        }
                    }
                }
                # INDEX STATS SCANMODE has no Ola equivalent (Ola does not
                # expose the fragmentation scan mode); logged in Discover only.
            }
        }

        # Exclusions -> @Databases = 'USER_DATABASES, -dbA, -dbB'
        # Treat OPTIMISE EXCLUDE and STATS EXCLUDE the same (Ola cannot split index vs stats per db).
        $excludedDbs = @(
            $LegacyConfigRows |
            Where-Object {
                ($_.ConfigName -eq 'OPTIMISE EXCLUDE' -or $_.ConfigName -eq 'STATS EXCLUDE') -and
                ($_.DatabaseConfigValue.ToString().Trim() -eq '1')
            } |
            Select-Object -ExpandProperty DatabaseName -Unique
        )
        if ($excludedDbs.Count -gt 0) {
            $list = @('USER_DATABASES') + ($excludedDbs | ForEach-Object { "-$_" })
            $ola.Databases = @{
                Value  = ($list -join ', ')
                Source = 'Legacy'
                Notes  = "Excluded via OPTIMISE/STATS EXCLUDE: $($excludedDbs -join ',')"
            }
        }
    }

    # --- Legacy step text (flow-control flags) ---
    $step1 = $LegacyJobSteps | Where-Object { $_.StepName -match 'Index' } | Select-Object -First 1
    if ($step1) {
        $p1 = Parse-LegacyStepParams $step1.StepCommand
        if ($p1.ContainsKey('RebuildHeap') -and $p1.RebuildHeap -eq 1) {
            $high = "$($ola.FragmentationHigh.Value)"
            if ($high -notmatch 'INDEX_REBUILD_OFFLINE') {
                $ola.FragmentationHigh = @{
                    Value  = "$high,INDEX_REBUILD_OFFLINE"
                    Source = 'Legacy'
                    Notes  = 'Heap rebuild requested (@RebuildHeap=1); heaps cannot rebuild online'
                }
            }
        }
    }

    $step2 = $LegacyJobSteps | Where-Object { $_.StepName -match 'Statistic' } | Select-Object -First 1
    if ($step2) {
        $p2 = Parse-LegacyStepParams $step2.StepCommand
        if ($p2.ContainsKey('StatisticAgeHours') -and $null -ne $p2.StatisticAgeHours) {
            $ageHours = [int]$p2.StatisticAgeHours
            if ($ageHours -lt 24) {
                # Legacy age threshold under a day -> every stat qualifies on daily or
                # weekly runs, matching Ola's 'N' (update all stats).
                $ola.OnlyModifiedStatistics = @{
                    Value  = 'N'
                    Source = 'Legacy'
                    Notes  = "Legacy @StatisticAgeHours=$ageHours; mapped to 'N' (update all) because threshold < 24h covers all stats on daily/weekly schedules"
                }
            }
            else {
                # Threshold >= 24h could be intentional age-gating (e.g. weekly job
                # with 48h threshold). Ola has no age-based filter; leave at default
                # and flag for human review.
                $ola.OnlyModifiedStatistics = @{
                    Value  = $DefaultOlaParams.OnlyModifiedStatistics
                    Source = 'Default'
                    Notes  = "Legacy @StatisticAgeHours=$ageHours exceeds 24h; possible intentional age-gating - verify whether 'Y' (modified-only) or 'N' (all stats) is correct"
                }
            }
        }
    }

    return $ola
}

function Build-IndexOptimizeCommand {
    param($OlaMap)
    $orderedKeys = @(
        'Databases', 'FragmentationLevel1', 'FragmentationLevel2',
        'FragmentationLow', 'FragmentationMedium', 'FragmentationHigh',
        'MinNumberOfPages', 'MaxNumberOfPages',
        'UpdateStatistics', 'OnlyModifiedStatistics',
        'LogToTable', 'TimeLimit'
    )
    $lines = @('EXEC dbo.IndexOptimize')
    for ($i = 0; $i -lt $orderedKeys.Count; $i++) {
        $k = $orderedKeys[$i]
        $v = $OlaMap[$k].Value
        $rendered =
        if ($null -eq $v) { 'NULL' }
        elseif ($v -is [int]) { "$v" }
        else { "'" + ($v.ToString() -replace "'", "''") + "'" }
        $prefix = if ($i -eq 0) { '  ' } else { ', ' }
        $lines += "$prefix@$k = $rendered"
    }
    return ($lines -join "`r`n") + ';'
}

# --------------------------------------------------------------------
# Phase: Discover
# --------------------------------------------------------------------
function Write-JobAudit {
    # Emits one audit row per job-level property, per step property, and per
    # schedule property. Prefix is 'Legacy' or 'New' (or any label) so the
    # same rows collate cleanly in Azure.
    param(
        [string]$SqlInstance,
        [System.Management.Automation.PSCredential]$Credential,
        [string]$Prefix,
        $Steps,
        $Schedules
    )
    if (-not $Steps -or @($Steps).Count -eq 0) {
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$Prefix.JobExists" -FindingValue 0
        return
    }

    $first = $Steps | Select-Object -First 1
    Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$Prefix.JobExists"      -FindingValue 1
    Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$Prefix.Job.Name"       -FindingValue $first.JobName
    Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$Prefix.Job.Enabled"    -FindingValue $first.JobEnabled
    Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$Prefix.Job.Owner"      -FindingValue $first.JobOwner
    Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$Prefix.Job.Category"   -FindingValue $first.JobCategory
    Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$Prefix.Job.Description" -FindingValue $first.JobDescription

    foreach ($s in $Steps) {
        $tag = "$Prefix.Step$($s.StepId)"
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$tag.StepName"        -FindingValue $s.StepName
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$tag.SubSystem"       -FindingValue $s.SubSystem
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$tag.DatabaseName"    -FindingValue $s.DatabaseName
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$tag.OutputFile"      -FindingValue $s.OutputFile
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$tag.OnSuccessAction" -FindingValue $s.OnSuccessAction
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$tag.OnSuccessStepId" -FindingValue $s.OnSuccessStepId
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$tag.OnFailAction"    -FindingValue $s.OnFailAction
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$tag.OnFailStepId"    -FindingValue $s.OnFailStepId
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$tag.RetryAttempts"   -FindingValue $s.RetryAttempts
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$tag.RetryInterval"   -FindingValue $s.RetryInterval
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$tag.Flags"           -FindingValue $s.Flags
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$tag.Command"         -FindingValue ('<see Notes>') -Notes $s.StepCommand
    }

    $idx = 0
    foreach ($sc in @($Schedules)) {
        if (-not $sc) { continue }
        $tag = "$Prefix.Schedule$idx"
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$tag.Name"                 -FindingValue $sc.name
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$tag.Enabled"              -FindingValue $sc.enabled
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$tag.FreqType"             -FindingValue $sc.freq_type
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$tag.FreqInterval"         -FindingValue $sc.freq_interval
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$tag.FreqSubdayType"       -FindingValue $sc.freq_subday_type
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$tag.FreqSubdayInterval"   -FindingValue $sc.freq_subday_interval
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$tag.FreqRelativeInterval" -FindingValue $sc.freq_relative_interval
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$tag.FreqRecurrenceFactor" -FindingValue $sc.freq_recurrence_factor
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$tag.ActiveStartDate"      -FindingValue $sc.active_start_date
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$tag.ActiveEndDate"        -FindingValue $sc.active_end_date
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$tag.ActiveStartTime"      -FindingValue $sc.active_start_time
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding "$tag.ActiveEndTime"        -FindingValue $sc.active_end_time
        $idx++
    }
}

function Invoke-Discover {
    param([string]$SqlInstance, [System.Management.Automation.PSCredential]$Credential)
    Write-Host "[Discover] $SqlInstance" -ForegroundColor Cyan

    $olaState = Get-OlaState -SqlInstance $SqlInstance -Credential $Credential
    Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding 'Ola.CommandExecute'  -FindingValue $olaState.HasCommandExecute
    Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding 'Ola.CommandLog'      -FindingValue $olaState.HasCommandLog
    Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding 'Ola.IndexOptimize'   -FindingValue $olaState.HasIndexOptimize

    # Full capture of legacy job (settings, steps, schedules)
    $legacySteps = Get-JobSteps     -SqlInstance $SqlInstance -Credential $Credential -JobName $LegacyJobName
    $legacySchedules = Get-JobSchedules -SqlInstance $SqlInstance -Credential $Credential -JobName $LegacyJobName
    Write-JobAudit -SqlInstance $SqlInstance -Credential $Credential -Prefix 'Legacy' -Steps $legacySteps -Schedules $legacySchedules

    # Full capture of the new job if one already exists on this server
    $newSteps = Get-JobSteps     -SqlInstance $SqlInstance -Credential $Credential -JobName $NewJobName
    $newSchedules = Get-JobSchedules -SqlInstance $SqlInstance -Credential $Credential -JobName $NewJobName
    Write-JobAudit -SqlInstance $SqlInstance -Credential $Credential -Prefix 'New' -Steps $newSteps -Schedules $newSchedules

    # tblDatabaseConfig: audit every row, flag unmapped keys as 'Unmapped'
    $cfg = Get-LegacyConfig -SqlInstance $SqlInstance -Credential $Credential
    if ($null -eq $cfg) {
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding 'Legacy.ConfigTable' -FindingValue 'Missing' `
            -Notes 'DBA.dbo.tblDatabaseConfig not found; mapping will fall through to defaults.'
    }
    else {
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding 'Legacy.ConfigTable' -FindingValue 'Present' `
            -Notes "Rows: $(@($cfg).Count)"
        foreach ($c in $cfg) {
            $tag = if ($c.DatabaseName) { "$($c.ConfigName)[$($c.DatabaseName)]" } else { $c.ConfigName }
            $source = if ($KnownConfigNames -contains $c.ConfigName) { 'Mapped' } else { 'Unmapped' }
            Write-Audit -SqlInstance $SqlInstance -Credential $Credential `
                -Finding "Legacy.Config.$tag" -FindingValue $c.DatabaseConfigValue -Source $source
        }
    }

    Write-Host "[Discover] complete. RunId=$RunId" -ForegroundColor Green
}

# --------------------------------------------------------------------
# Phase: InstallPrereqs
# --------------------------------------------------------------------
function Invoke-InstallPrereqs {
    param([string]$SqlInstance, [System.Management.Automation.PSCredential]$Credential)
    Write-Host "[InstallPrereqs] $SqlInstance" -ForegroundColor Cyan

    $state = Get-OlaState -SqlInstance $SqlInstance -Credential $Credential
    if ($state.HasCommandExecute -eq 1 -and $state.HasCommandLog -eq 1 -and $state.HasIndexOptimize -eq 1) {
        Write-Host '  framework already present; no-op' -ForegroundColor Green
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding 'InstallPrereqs' -FindingValue 'NoOp'
        return
    }

    Invoke-Sql -SqlInstance $SqlInstance -Credential $Credential -Query "IF DB_ID('DBA') IS NULL CREATE DATABASE DBA;"

    # Procs only - NOT -InstallJobs. Does not create/touch any SQL Agent jobs,
    # including DatabaseBackup (brief §3, §5).
    Install-DbaMaintenanceSolution `
        -SqlInstance   $SqlInstance `
        -SqlCredential $Credential `
        -Database      DBA `
        -Solution      IndexOptimize `
        -LogToTable `
        -EnableException

    Write-Host '  framework installed (CommandExecute, CommandLog, IndexOptimize)' -ForegroundColor Green
    Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding 'InstallPrereqs' -FindingValue 'Installed'
}

# --------------------------------------------------------------------
# Phase: Deploy
# --------------------------------------------------------------------
function Invoke-Deploy {
    param([string]$SqlInstance, [System.Management.Automation.PSCredential]$Credential)
    Write-Host "[Deploy] $SqlInstance" -ForegroundColor Cyan

    $state = Get-OlaState -SqlInstance $SqlInstance -Credential $Credential
    if ($state.HasIndexOptimize -eq 0) {
        throw "Ola IndexOptimize procedure is missing on $SqlInstance. Run -Phase InstallPrereqs first."
    }

    $legacySteps = Get-JobSteps     -SqlInstance $SqlInstance -Credential $Credential -JobName $LegacyJobName
    $legacyConfig = Get-LegacyConfig -SqlInstance $SqlInstance -Credential $Credential
    $legacySched = Get-JobSchedules -SqlInstance $SqlInstance -Credential $Credential -JobName $LegacyJobName |
    Select-Object -First 1

    $olaMap = Build-OlaParams -LegacyJobSteps $legacySteps -LegacyConfigRows $legacyConfig

    foreach ($k in $olaMap.Keys) {
        $entry = $olaMap[$k]
        $val = if ($null -eq $entry.Value) { $null } else { "$($entry.Value)" }
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential `
            -Finding "Deploy.Param.$k" -FindingValue $val -Source $entry.Source -Notes $entry.Notes
    }

    $command = Build-IndexOptimizeCommand -OlaMap $olaMap
    Write-Host "`nIndexOptimize command to be installed:" -ForegroundColor DarkCyan
    Write-Host $command -ForegroundColor DarkGray
    Write-Host ''

    # Drop any pre-existing IndexOptimize variant so redeploy is clean.
    # Matches '%IndexOptimi[sz]e%USER_DATABASES%' only - backup/CommandLog cleanup jobs untouched.
    $existingNew = Invoke-Sql -SqlInstance $SqlInstance -Credential $Credential -Query @"
SELECT name FROM msdb.dbo.sysjobs
WHERE name LIKE N'%IndexOptimi[sz]e%USER[_]DATABASES%';
"@
    foreach ($row in @($existingNew)) {
        if (-not $row -or -not $row.name) { continue }
        Invoke-Sql -SqlInstance $SqlInstance -Credential $Credential -Query @"
EXEC msdb.dbo.sp_delete_job @job_name = N'$(($row.name) -replace "'","''")', @delete_unused_schedule = 1;
"@
        Write-Host "  removed existing job '$($row.name)'" -ForegroundColor DarkYellow
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding 'Deploy.RemovedExisting' -FindingValue $row.name
    }

    # Choose schedule: legacy verbatim, else documented default.
    if ($legacySched) {
        $sched = @{
            Source                 = 'Legacy'
            Name                   = "$($legacySched.name)"
            Enabled                = [int]$legacySched.enabled
            Freq_Type              = [int]$legacySched.freq_type
            Freq_Interval          = [int]$legacySched.freq_interval
            Freq_Subday_Type       = [int]$legacySched.freq_subday_type
            Freq_Subday_Interval   = [int]$legacySched.freq_subday_interval
            Freq_Relative_Interval = [int]$legacySched.freq_relative_interval
            Freq_Recurrence_Factor = [int]$legacySched.freq_recurrence_factor
            Active_Start_Date      = [int]$legacySched.active_start_date
            Active_End_Date        = [int]$legacySched.active_end_date
            Active_Start_Time      = [int]$legacySched.active_start_time
            Active_End_Time        = [int]$legacySched.active_end_time
        }
    }
    else {
        $sched = @{
            Source                 = 'Default'
            Name                   = $DefaultSchedule.Name
            Enabled                = [int]$DefaultSchedule.Enabled
            Freq_Type              = [int]$DefaultSchedule.Freq_Type
            Freq_Interval          = [int]$DefaultSchedule.Freq_Interval
            Freq_Subday_Type       = [int]$DefaultSchedule.Freq_Subday_Type
            Freq_Subday_Interval   = [int]$DefaultSchedule.Freq_Subday_Interval
            Freq_Relative_Interval = [int]$DefaultSchedule.Freq_Relative_Interval
            Freq_Recurrence_Factor = [int]$DefaultSchedule.Freq_Recurrence_Factor
            Active_Start_Date      = [int]$DefaultSchedule.Active_Start_Date
            Active_End_Date        = [int]$DefaultSchedule.Active_End_Date
            Active_Start_Time      = [int]$DefaultSchedule.Active_Start_Time
            Active_End_Time        = [int]$DefaultSchedule.Active_End_Time
        }
    }
    Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding 'Deploy.Schedule.Source'    -FindingValue $sched.Source -Source $sched.Source
    Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding 'Deploy.Schedule.Name'     -FindingValue $sched.Name
    Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding 'Deploy.Schedule.FreqType' -FindingValue $sched.Freq_Type
    Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding 'Deploy.Schedule.StartTime' -FindingValue $sched.Active_Start_Time

    # Review flag: any time a mappable parameter or the schedule falls back to
    # documented defaults, emit a single summary 'Warning' row so the Inventory
    # Server can list servers that need human review. Does not block Deploy.
    $hasLegacyJob = @($legacySteps).Count -gt 0
    $mappableOla = @(
        'FragmentationLevel1', 'FragmentationLevel2',
        'MinNumberOfPages', 'MaxNumberOfPages',
        'FragmentationHigh', 'FragmentationMedium',
        'Databases', 'OnlyModifiedStatistics'
    )
    $defaultedMappable = @($mappableOla | Where-Object { $olaMap[$_].Source -eq 'Default' })
    $reviewReasons = @()
    if ($defaultedMappable.Count -gt 0) {
        if ($hasLegacyJob) {
            $reviewReasons += "Legacy job present but mappable params fell back to defaults: $($defaultedMappable -join ', '). See per-param Deploy.Param.* rows for reasoning."
        }
        else {
            $reviewReasons += "No legacy job on this server; mappable params defaulted: $($defaultedMappable -join ', ')"
        }
    }
    if ($sched.Source -eq 'Default') {
        $reviewReasons += 'Schedule defaulted to 22:00 daily (no legacy schedule found)'
    }
    if ($reviewReasons.Count -gt 0) {
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential `
            -Finding 'Deploy.ReviewRequired' -FindingValue 'True' -Source 'Warning' `
            -Notes ($reviewReasons -join ' | ')
        Write-Host "  review flag raised: $($reviewReasons -join ' | ')" -ForegroundColor Yellow
    }

    $escCmd = $command -replace "'", "''"
    $escSchedName = $sched.Name -replace "'", "''"

    $createSql = @"
USE msdb;
DECLARE @jobId BINARY(16);

EXEC msdb.dbo.sp_add_job
    @job_name                  = N'$NewJobName',
    @enabled                   = 0,
    @description               = N'Ola IndexOptimize - deployed via rollout script, RunId $RunId',
    @category_name             = N'[Uncategorized (Local)]',
    @owner_login_name          = N'sa',
    @notify_level_eventlog     = 0,
    @notify_level_email        = 2,
    @notify_email_operator_name = N'DBA',
    @job_id                    = @jobId OUTPUT;

EXEC msdb.dbo.sp_add_jobserver @job_name = N'$NewJobName', @server_name = N'(local)';

EXEC msdb.dbo.sp_add_jobstep
    @job_name          = N'$NewJobName',
    @step_name         = N'IndexOptimize - USER_DATABASES',
    @subsystem         = N'TSQL',
    @database_name     = N'DBA',
    @command           = N'$escCmd',
    @on_success_action = 1,
    @on_fail_action    = 2,
    @retry_attempts    = 0,
    @retry_interval    = 0;

EXEC msdb.dbo.sp_add_jobschedule
    @job_name               = N'$NewJobName',
    @name                   = N'$escSchedName',
    @enabled                = $($sched.Enabled),
    @freq_type              = $($sched.Freq_Type),
    @freq_interval          = $($sched.Freq_Interval),
    @freq_subday_type       = $($sched.Freq_Subday_Type),
    @freq_subday_interval   = $($sched.Freq_Subday_Interval),
    @freq_relative_interval = $($sched.Freq_Relative_Interval),
    @freq_recurrence_factor = $($sched.Freq_Recurrence_Factor),
    @active_start_date      = $($sched.Active_Start_Date),
    @active_end_date        = $($sched.Active_End_Date),
    @active_start_time      = $($sched.Active_Start_Time),
    @active_end_time        = $($sched.Active_End_Time);
"@
    Invoke-Sql -SqlInstance $SqlInstance -Credential $Credential -Query $createSql

    Write-Host "  created '$NewJobName' (disabled)" -ForegroundColor Green
    Write-Host "  validate by running the job manually, then run -Phase Cutover" -ForegroundColor Yellow
}

# --------------------------------------------------------------------
# Phase: Cutover
# --------------------------------------------------------------------
function Invoke-Cutover {
    param([string]$SqlInstance, [System.Management.Automation.PSCredential]$Credential)
    Write-Host "[Cutover] $SqlInstance" -ForegroundColor Cyan

    $check = Invoke-Sql -SqlInstance $SqlInstance -Credential $Credential -Query @"
SELECT
    (SELECT COUNT(1) FROM msdb.dbo.sysjobs WHERE name = N'$NewJobName')   AS NewExists,
    (SELECT COUNT(1) FROM msdb.dbo.sysjobs WHERE name = N'$LegacyJobName') AS LegacyExists;
"@
    if ($check.NewExists -eq 0) {
        throw "$NewJobName does not exist on $SqlInstance. Run -Phase Deploy first."
    }

    $sql = @"
BEGIN TRY
    BEGIN TRAN;
    IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'$LegacyJobName')
        EXEC msdb.dbo.sp_update_job @job_name = N'$LegacyJobName', @enabled = 0;
    EXEC msdb.dbo.sp_update_job @job_name = N'$NewJobName', @enabled = 1;
    COMMIT TRAN;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    THROW;
END CATCH
"@
    Invoke-Sql -SqlInstance $SqlInstance -Credential $Credential -Query $sql

    if ($check.LegacyExists -eq 0) {
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential `
            -Finding 'Cutover.Legacy' -FindingValue 'Skipped' -Source 'NoLegacy' `
            -Notes "Legacy job '$LegacyJobName' not present on this server; nothing to disable."
        Write-Host "  no legacy job on this server; new job enabled as greenfield deploy" -ForegroundColor Yellow
    }
    else {
        Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding 'Cutover.Legacy' -FindingValue 'Disabled' -Notes "job: $LegacyJobName"
        Write-Host "  cutover complete. Legacy retained (disabled) for 30 days per brief §11." -ForegroundColor Green
    }
    Write-Audit -SqlInstance $SqlInstance -Credential $Credential -Finding 'Cutover.New'    -FindingValue 'Enabled'  -Notes "job: $NewJobName"
}

# --------------------------------------------------------------------
# Main
# --------------------------------------------------------------------
Write-Host "ServerName = $ServerName   Phase = $Phase   RunId = $RunId" -ForegroundColor Cyan
$cred = Get-ResolvedCredential -SqlInstance $ServerName
Ensure-AuditTable -SqlInstance $ServerName -Credential $cred

switch ($Phase) {
    'Discover' { Invoke-Discover       -SqlInstance $ServerName -Credential $cred }
    'InstallPrereqs' { Invoke-InstallPrereqs -SqlInstance $ServerName -Credential $cred }
    'Deploy' { Invoke-Deploy         -SqlInstance $ServerName -Credential $cred }
    'Cutover' { Invoke-Cutover        -SqlInstance $ServerName -Credential $cred }
}

Write-Host "`nDone. RunId=$RunId" -ForegroundColor Cyan
