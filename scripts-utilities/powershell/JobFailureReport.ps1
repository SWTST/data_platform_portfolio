#Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
Set-DbatoolsConfig -FullName sql.connection.trustcert -Value $true -Register
Write-Output "JobFailureReport.ps1 started at $(Get-Date)"

#Global Variables <Start>

$Auth1Creds = Get-Credential -UserName "" -Message 'Input Auth1 Credentials'
$Auth2Creds = Get-Credential -Message 'Input Auth2 Credentials'

$cmsServer = 'CMS-SERVER01'
$allServers = Get-DbaRegServer -SqlInstance $cmsServer -SqlCredential $Auth2Creds

<# SEND EMAIL FUNCTION
$JobReport = @("\\servername\C$\SQLstuff\JobFailureReporting\Listeners.csv")
$SingleInstancesReport = "\\servername\C$\SQLstuff\JobFailureReporting\SingleInstances.csv"
$JobReport += $SingleInstancesReport
#>

$Query = "
DECLARE @sql NVARCHAR(max)DECLARE @sql2 NVARCHAR(max)DECLARE @Listener NVARCHAR(max)
IF ((SELECT TOP 1 dns_name from sys.availability_group_listeners) IS NOT NULL )
BEGIN
SELECT TOP 1 @Listener = dns_name from sys.availability_group_listeners
SET @sql = 'USE msdb
DECLARE @current_date DATE = GETDATE()
DECLARE @past_date DATE = DATEADD(day,-2,@current_date)
SELECT
    '''+ @Listener + ''' AS [ServerName],
    [JobName] = J.name,
    ISNULL(F.Failures, 0) AS Failures,
    L.Last_Run_Outcome AS [LastRunOutcome]
FROM
    msdb.dbo.sysjobs AS J
    CROSS APPLY (
        SELECT COUNT(job_id) AS Failures
        FROM msdb.dbo.sysjobhistory AS T
        WHERE T.job_id = J.job_id
        AND run_status = 0
        AND step_id = 0
        AND CAST(CONVERT(DATE, CAST(run_date AS CHAR(8))) AS DATE) 
        BETWEEN @past_date AND @current_date
        GROUP BY job_id
    ) F
    CROSS APPLY (
        SELECT TOP 1
        CASE
            WHEN run_status = 0 THEN ''Failure''
            WHEN run_status = 1 THEN ''Success''
            WHEN run_status = 2 THEN ''Retry''
            WHEN run_status = 3 THEN ''Canceled''
            WHEN run_status = 4 THEN ''In Progress'' 
        END AS Last_Run_Outcome
        FROM msdb.dbo.sysjobhistory T
        WHERE T.job_id = J.job_id
        AND step_id = 0
        AND CAST(CONVERT(DATE, CAST(run_date AS CHAR(8))) AS DATE) 
        BETWEEN @past_date AND @current_date
        ORDER BY instance_id DESC
    ) L
ORDER BY
    J.name'
EXEC(@sql)
END

ELSE
BEGIN 
SET @sql2 = 'USE msdb
DECLARE @current_date DATE = GETDATE()
DECLARE @past_date DATE = DATEADD(day,-2,@current_date)
SELECT
    @@SERVERNAME AS [ServerName],
    JobName = J.name,
    ISNULL(F.Failures, 0) AS Failures,
    L.Last_Run_Outcome AS [LastRunOutcome]
FROM
    msdb.dbo.sysjobs AS J
    CROSS APPLY (
        SELECT COUNT(job_id) AS Failures
        FROM msdb.dbo.sysjobhistory AS T
        WHERE T.job_id = J.job_id
        AND run_status = 0
        AND step_id = 0
        AND CAST(CONVERT(DATE, CAST(run_date AS CHAR(8))) AS DATE) 
        BETWEEN @past_date AND @current_date
        GROUP BY job_id
    ) F
    CROSS APPLY (
        SELECT TOP 1
        CASE
            WHEN run_status = 0 THEN ''Failure''
            WHEN run_status = 1 THEN ''Success''
            WHEN run_status = 2 THEN ''Retry''
            WHEN run_status = 3 THEN ''Canceled''
            WHEN run_status = 4 THEN ''In Progress'' 
        END AS Last_Run_Outcome
        FROM msdb.dbo.sysjobhistory T
        WHERE T.job_id = J.job_id
        AND step_id = 0
        AND CAST(CONVERT(DATE, CAST(run_date AS CHAR(8))) AS DATE) 
        BETWEEN @past_date AND @current_date
        ORDER BY instance_id DESC
    ) L
ORDER BY
    J.name'
EXEC(@sql2)
END
"

$results = @()

#Global Variables <End>

#Run report
foreach($server in $allServers) {
    try{
    #Auth2
    Write-Host('Trying Auth2 on $server.ServerName')
    $results += Invoke-DBAQuery -SqlInstance $server.ServerName -Query $Query -SqlCredential $Auth2Creds -EnableException
    Write-Host('Auth2 succeeded on $server.ServerName')
    continue
    } catch {

    #Auth1
    Write-Warning "Auth2 failed on $($server.ServerName): $($_.Exception.Message)"

        try {
            Write-Host('Trying Auth1 on $server.ServerName')
            $results += Invoke-DBAQuery -SqlInstance $server.ServerName -Query $Query -SqlCredential $Auth1Creds -EnableException
            Write-Host('Auth1 succeeded on $server.ServerName')
        } catch {
            Write-Warning "Auth2 and Auth1 failed on $($server.ServerName): $($_.Exception.Message)"
        }
    }
}

$results | Format-Table -AutoSize

Write-Output "JobFailureReport.ps1 ended at $(Get-Date)"


<#  SEND EMAIL FUNCTION
#File Operations - Prep for HTML
$CSVData = Import-Csv -Path "\\servername\C$\SQLstuff\JobFailureReporting\Listeners.csv"
$CSVData2 = Import-Csv -Path "\\servername\C$\SQLstuff\JobFailureReporting\SingleInstances.csv"


#Convert CSV Data to HTML
If($CSVData.Count -gt 0) {
    $htmlTable = $CSVData | ConvertTo-Html -Property ServerName, JobName, Failures, LastRunOutcome -As Table
} else {
    $htmlTable = "<p>There were no Job failures for Listeners for the past 2 days.</p>"
}

if($CSVData2.Count -gt 0) {
    $htmlTable2 = $CSVData2 | ConvertTo-Html -Property ServerName, JobName, Failures, LastRunOutcome -As Table
} else {
    $htmlTable2 = "<p>There were no Job failures for Single Instances for the past 2 days.</p>"
}

#$htmlTable | Out-File -FilePath "\\servername\C$\SQLstuff\JobFailureReporting\Listeners.html"
#$htmlTable2 | Out-File -FilePath "\\servername\C$\SQLstuff\JobFailureReporting\SingleInstances.html"

$body = @"
<html>
   <head>
      <style>table {border-collapse: 100%;}th, td {border: 1px solid black; padding: 8px; text-align: left;}th {background-color: #f2f2f2;}</style>
   </head>
   <body>
      <h1><u>SQL Job Failure Report</u></h1>
      <p>This report outlines SQL Job failures across the estate from the past 2 days. The current schedule runs reports on Monday, Wednesday & Friday at 08:00.</p>
      <h2>Listeners</h2>
      $htmlTable<br><br>
      <h2>Single Instances</h2>
      $htmlTable2
   </body>
</html>
"@


$sendMailMessageSplat = @{
    From = 'dba-team@contoso.com'
    To = 'servicedesk@contoso.com'
    CC = 'recipient@contoso.com'
    Subject = 'Job Failure Report ' + $CurrentDate
    ##Attachments = $JobReport
    Body = $body
    SmtpServer = 'smtp.contoso.local'
}

Send-MailMessage @sendMailMessageSplat -BodyAsHtml
#>

