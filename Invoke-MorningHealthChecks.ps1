# -----------------------------------------------------------------------------
# Author:      Patrick Keisler, Microsoft
# Date:        Nov 2017
#
# History:
# Date         Name                     Comment
# -----------  -----------------------  ----------------------------------------
# 06 Nov 2017  Patrick Keisler (MSFT)   Created
#
# File Name:   Invoke-MorningHealthChecks.ps1
#
# Purpose:     PowerShell script to automate morning health checks.
#
# -----------------------------------------------------------------------------
#
# Copyright (C) 2017 Microsoft Corporation
#
# Disclaimer:
#   This is SAMPLE code that is NOT production ready. It is the sole intention of this code to provide a proof of concept as a
#   learning tool for Microsoft Customers. Microsoft does not provide warranty for or guarantee any portion of this code
#   and is NOT responsible for any affects it may have on any system it is executed on  or environment it resides within.
#   Please use this code at your own discretion!
# Additional legalese:
#   This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
#   THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#   INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
#   We grant You a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
#   the object code form of the Sample Code, provided that You agree:
#       (i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
#      (ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
#     (iii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims or lawsuits, including attorneys' fees,
#           that arise or result from the use or distribution of the Sample Code.
# -----------------------------------------------------------------------------
#
# Paramaters:
#   $cmsServer - Name of the CMS server where your list of SQL Servers is registered.
#   $cmsGroup - Name of the CMS group that will be evaluated.
#   $serverList - Comma delimited list of SQL Servers that will be evaluated.
#
# Important note: 
#   Either "$cmsServer/$cmsGroup" or "$serverList" parameter should have values specified, but NOT BOTH.
#
# Example 1 uses the CMS parameters to check servers in the 'SQL2012' CMS group that is a subfolder of 'PROD':
#   Invoke-MorningHealthChecks.ps1 -cmsServer 'SOLO\CMS' -cmsGroup 'PROD\SQL2012'
#
# Example 2 uses the $serverList paramenter to check 4 different SQL Servers:
#   Invoke-MorningHealthChecks.ps1 -serverList 'CHEWIE','CHEWIE\SQL01','LUKE\SKYWALKER','LANDO\CALRISSIAN'
#
# -----------------------------------------------------------------------------

####################   SCRIPT-LEVEL PARAMETERS   ########################
param(
  [CmdletBinding()]
  [Parameter(ParameterSetName='Set1',Position=0,Mandatory=$true)][String]$cmsServer,
  [parameter(ParameterSetName='Set1',Position=1,Mandatory=$false)][String]$cmsGroup,
  [parameter(ParameterSetName='Set2',Position=2,Mandatory=$true)][String[]]$serverList
)

####################   LOAD ASSEMBLIES   ########################

#Attempt to load assemblies by name starting with the latest version
try {
  #SMO v14 - SQL Server 2017
  Add-Type -AssemblyName 'Microsoft.SqlServer.ConnectionInfo, Version=14.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
  Add-Type -AssemblyName 'Microsoft.SqlServer.Management.RegisteredServers, Version=14.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
}
catch {
  try {
    #SMO v13 - SQL Server 2016
    Add-Type -AssemblyName 'Microsoft.SqlServer.ConnectionInfo, Version=13.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
    Add-Type -AssemblyName 'Microsoft.SqlServer.Management.RegisteredServers, Version=13.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
  }
  catch {
    try {
      #SMO v12 - SQL Server 2014
      Add-Type -AssemblyName 'Microsoft.SqlServer.ConnectionInfo, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
      Add-Type -AssemblyName 'Microsoft.SqlServer.Management.RegisteredServers, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
    }
    catch {
      try {
        #SMO v11 - SQL Server 2012
        Add-Type -AssemblyName 'Microsoft.SqlServer.ConnectionInfo, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
        Add-Type -AssemblyName 'Microsoft.SqlServer.Management.RegisteredServers, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91' -ErrorAction Stop
      }
      catch {
        Write-Warning 'SMO components not installed. Download from https://goo.gl/E700bG'
        Break
      }
    }
  }
}

####################   FUNCTIONS   ########################
function Get-Error {
  <#
      .SYNOPSIS
      Processes errors encoutered in PowerShell code.
      .DESCRIPTION
      The Get-SqlConnection function processes either PowerShell errors or application errors defined within your code.
      .INPUTS
      None
      .OUTPUTS
      None
      .EXAMPLE
      try { 1/0 } catch { Get-Error $Error }
      This passes the common error object (System.Management.Automation.ErrorRecord) for processing.
      .EXAMPLE
      try { 1/0 } catch { Get-Error "You attempted to divid by zero. Try again." }
      This passes a string that is output as an error message.
      .LINK
      Get-SqlConnection 
  #>
  param(
    [CmdletBinding()]
    [Parameter(Position=0,ParameterSetName='PowerShellError',Mandatory=$true)] [System.Management.Automation.ErrorRecord]$PSError,
    [Parameter(Position=0,ParameterSetName='ApplicationError',Mandatory=$true)] [string]$AppError
  )

  if ($PSError) {
    #Process a PowerShell error
    Write-Host '******************************'
    Write-Host "Error Count: $($PSError.Count)"
    Write-Host '******************************'

    $err = $PSError.Exception
    Write-Host $err.Message
    $err = $err.InnerException
    while ($err.InnerException) {
      Write-Host $err.InnerException.Message
      $err = $err.InnerException
    }
    Throw
  }
  elseif ($AppError) {
    #Process an application error
    Write-Host '******************************'
    Write-Host 'Error Count: 1'
    Write-Host '******************************'
    Write-Host $AppError
    Throw
  }
} #Get-Error

function Get-SqlConnection {
  <#
      .SYNOPSIS
      Gets a ServerConnection.
      .DESCRIPTION
      The Get-SqlConnection function  gets a ServerConnection to the specified SQL Server.
      .INPUTS
      None
      You cannot pipe objects to Get-SqlConnection 
      .OUTPUTS
      Microsoft.SqlServer.Management.Common.ServerConnection
      Get-SqlConnection returns a Microsoft.SqlServer.Management.Common.ServerConnection object.
      .EXAMPLE
      Get-SqlConnection "Z002\sql2K8"
      This command gets a ServerConnection to SQL Server Z002\SQL2K8.
      .EXAMPLE
      Get-SqlConnection "Z002\sql2K8" "sa" "Passw0rd"
      This command gets a ServerConnection to SQL Server Z002\SQL2K8 using SQL authentication.
      .LINK
      Get-SqlConnection 
  #>
  param(
    [CmdletBinding()]
    [Parameter(Mandatory=$true)] [string]$sqlserver,
    [string]$username, 
    [string]$password,
    [Parameter(Mandatory=$false)] [string]$applicationName='Morning Health Checks'
  )

  Write-Verbose "Get-SqlConnection $sqlserver"
    
    if($Username -and $Password){
        try { $con = new-object ('Microsoft.SqlServer.Management.Common.ServerConnection') $sqlserver,$username,$password }
        catch { Get-Error $_ }
    }
    else {
        try { $con = new-object ('Microsoft.SqlServer.Management.Common.ServerConnection') $sqlserver }
        catch { Get-Error $_ }
    }
	
  $con.ApplicationName = $applicationName
  $con.Connect()

  Write-Output $con
    
} #Get-ServerConnection

function Get-CmsServer {
  <#
      .SYNOPSIS
      Returns a list of SQL Servers from a CMS server.

      .DESCRIPTION
      Parses registered servers in CMS to return a list of SQL Servers for processing.

      .INPUTS
      None
      You cannot pipe objects to Get-CmsServer 

      .OUTPUTS
      Get-CmsServer returns an array of strings.
 
      .PARAMETER cmsServer
      The name of the CMS SQL Server including instance name.

      .PARAMETER cmsGroup
      OPTIONAL. The name of a group (and path) in the CMS server.

      .PARAMETER recurse
      OPTIONAL. Return all servers that may exist in subfolders below cmsFolder.

      .PARAMETER unique
      OPTIONAL. Returns a unique list of servers. This is helpful if you have the same SQL server registered in multiple groups.

      .NOTES
      Includes code from Chrissy LeMarie (@cl).
      https://blog.netnerds.net/smo-recipes/central-management-server/

      .EXAMPLE
      Get-CmsServer -cmsServer "SOLO\CMS"
      Returns a list of all registered servers that are on the CMS server.

      .EXAMPLE
      Get-CmsServer -cmsServer "SOLO\CMS" -cmsFolder "SQL2012" -recurse
      Returns a list of all registered servers that are in the SQL2012 folder and any subfolders that exist below it.

      .EXAMPLE
      Get-CmsServer -cmsServer "SOLO\CMS" -cmsFolder "SQL2012\Cluster" -unique
      Returns a list of all unique (distinct) registered servers that are in the folder for this exact path "SQL2012\Cluster".

      .LINK
      http://www.patrickkeisler.com/
  #>
  Param (
    [CmdletBinding()]
    [parameter(Position=0,Mandatory=$true)][ValidateNotNullOrEmpty()]$cmsServer,
    [parameter(Position=1)][String]$cmsGroup,
    [parameter(Position=2)][Switch]$recurse,
    [parameter(Position=3)][Switch]$unique
  ) 

  switch ($cmsServer.GetType().Name) {
    'String' { 
      try {
        $sqlConnection = Get-SqlConnection -sqlserver $cmsServer
        $cmsStore = new-object Microsoft.SqlServer.Management.RegisteredServers.RegisteredServersStore($sqlConnection)
      }
      catch {
        Get-Error $_
      }
    }
    'RegisteredServersStore' { $cmsStore = $cmsServer }
    default { Get-Error "Get-CmsGroup:Param `$cmsStore must be a String or ServerConnection object." }
  }

  Write-Verbose "Get-CmsServer $($cmsStore.DomainInstanceName) $cmsGroup $recurse $unique"

  ############### Declarations ###############

  $collection = @()
  $newcollection = @()
  $serverList = @()
  $cmsFolder = $cmsGroup.Trim('\')

  ############### Functions ###############

  Function Parse-ServerGroup {
    Param (
      [CmdletBinding()]
      [parameter(Position=0)][Microsoft.SqlServer.Management.RegisteredServers.ServerGroup]$serverGroup,
      [parameter(Position=1)][System.Object]$collection
    )

    #Get registered instances in this group.
    foreach ($instance in $serverGroup.RegisteredServers) {
      $urn = $serverGroup.Urn
      $group = $serverGroup.Name
      $fullGroupName = $null
 
      for ($i = 0; $i -lt $urn.XPathExpression.Length; $i++) {
        $groupName = $urn.XPathExpression[$i].GetAttributeFromFilter('Name')
        if ($groupName -eq 'DatabaseEngineServerGroup') { $groupName = $null }
        if ($i -ne 0 -and $groupName -ne 'DatabaseEngineServerGroup' -and $groupName.Length -gt 0 ) {
          $fullGroupName += "$groupName\"
        }
      }

      #Add a new object for each registered instance.
      $object = New-Object PSObject -Property @{
        Server = $instance.ServerName
        Group = $groupName
        FullGroupPath = $fullGroupName
      }
      $collection += $object
    }
 
    #Loop again if there are more sub groups.
    foreach($group in $serverGroup.ServerGroups)
    {
      $newobject = (Parse-ServerGroup -serverGroup $group -collection $newcollection)
      $collection += $newobject     
    }
    return $collection
  }

  ############### Main Execution Get-CmsServer ###############

  #Get a list of all servers in the CMS store
  foreach ($serverGroup in $cmsStore.DatabaseEngineServerGroup) {  
    $serverList = Parse-ServerGroup -serverGroup $serverGroup -collection $newcollection
  }

  #Set default to recurse if $cmsFolder is blank
  if ($cmsFolder -eq '') {$recurse = $true}

  if(($cmsFolder.Split('\')).Count -gt 1) {
    if($recurse.IsPresent) {
      #Return ones in this folder and subfolders
      $cmsFolder = "*$cmsFolder\*"
      if($unique.IsPresent) {
        $output = $serverList | Where-Object {$_.FullGroupPath -like $cmsFolder} | Select-Object Server -Unique
      }
      else {
        $output = $serverList | Where-Object {$_.FullGroupPath -like $cmsFolder} | Select-Object Server
      }
    }
    else {
      #Return only the ones in this folder
      $cmsFolder = "$cmsFolder\"
      if($unique.IsPresent) {
        $output = $serverList | Where-Object {$_.FullGroupPath -eq $cmsFolder} | Select-Object Server -Unique
      }
      else {
        $output = $serverList | Where-Object {$_.FullGroupPath -eq $cmsFolder} | Select-Object Server
      }
    }
  }
  elseif (($cmsFolder.Split('\')).Count -eq 1 -and $cmsFolder.Length -ne 0) {
    if($recurse.IsPresent) {
      #Return ones in this folder and subfolders
      $cmsFolder = "*$cmsFolder\*"
      if($unique.IsPresent) {
        $output = $serverList | Where-Object {$_.FullGroupPath -like $cmsFolder} | Select-Object Server -Unique
      }
      else {
        $output = $serverList | Where-Object {$_.FullGroupPath -like $cmsFolder} | Select-Object Server
      }
    }
    else {
      #Return only the ones in this folder
      if($unique.IsPresent) {
        $output = $serverList | Where-Object {$_.Group -eq $cmsFolder} | Select-Object Server -Unique
      }
      else {
        $output = $serverList | Where-Object {$_.Group -eq $cmsFolder} | Select-Object Server
      }
    }
  }
  elseif ($cmsFolder -eq '' -or $cmsFolder -eq $null) {
    if($recurse.IsPresent) {
      if($unique.IsPresent) {
        $output = $serverList | Select-Object Server -Unique
      }
      else {
        $output = $serverList | Select-Object Server
      }
    }
    else {
      if($unique.IsPresent) {
        $output = $serverList | Where-Object {$_.Group -eq $null} | Select-Object Server -Unique
      }
      else {
        $output = $serverList | Where-Object {$_.Group -eq $null} | Select-Object Server
      }
    }
  }
  
  #Convert the output a string array
  [string[]]$outputArray = $null
  $output | ForEach-Object {$outputArray += $_.Server}
  Write-Output $outputArray
} #Get-CmsServer

function Get-SqlUpTime {
  Param (
    [CmdletBinding()]
    [parameter(Position=0,Mandatory=$true)][ValidateNotNullOrEmpty()]$targetServer
    )

    $server = Get-SqlConnection $targetServer

    #Get startup time
    $cmd = "SELECT sqlserver_start_time FROM sys.dm_os_sys_info;"
    try {
        $sqlStartupTime = $server.ExecuteScalar($cmd)
    }
    catch {
        Get-Error $_
    }

    $upTime = (New-TimeSpan -Start ($sqlStartupTime) -End ($script:startTime))

    #Display the results to the console
    if ($upTime.Days -eq 0 -and $upTime.Hours -le 6) {
        #Critical if uptime is less than 6 hours
        Write-Host "`nCRITICAL:" -BackgroundColor Red -ForegroundColor White -NoNewline; Write-Host " $($server.TrueName)"
        Write-Host "Uptime: $($upTime.Days).$($upTime.Hours):$($upTime.Minutes):$($upTime.Seconds)"
    }
    elseif ($upTime.Days -lt 1 -and $upTime.Hours -gt 6) {
        #Warning if uptime less than 1 day but greater than 6 hours
        Write-Host "`nWARNING:" -BackgroundColor Yellow -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)"
        Write-Host "Uptime: $($upTime.Days).$($upTime.Hours):$($upTime.Minutes):$($upTime.Seconds)"
    }
    else {
        #Good if uptime is greater than 1 day
        Write-Host "`nGOOD:" -BackgroundColor Green -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)"
        Write-Host "Uptime: $($upTime.Days).$($upTime.Hours):$($upTime.Minutes):$($upTime.Seconds)"
    }
} #Get-SqlUptime

function Get-DatabaseStatus {
  Param (
    [CmdletBinding()]
    [parameter(Position=0,Mandatory=$true)][ValidateNotNullOrEmpty()]$targetServer
    )

    #Get status of each database
    $server = Get-SqlConnection $targetServer

    $cmd = "SELECT [name] AS [database_name], state_desc FROM sys.databases;"
    try {
        $results = $server.ExecuteWithResults($cmd)
    }
    catch {
        Get-Error $_
    }

    #Display the results to the console
    if ($results.Tables[0] | Where-Object {$_.state_desc -eq 'SUSPECT'}) {
        Write-Host "`nCRITICAL:" -BackgroundColor Red -ForegroundColor White -NoNewline; Write-Host " $($server.TrueName)"
    }
    elseif ($results.Tables[0] | Where-Object {$_.state_desc -in 'RESTORING','RECOVERING','RECOVERY_PENDING','EMERGENCY','OFFLINE','COPYING','OFFLINE_SECONDARY'}) {
        Write-Host "`nWARNING:" -BackgroundColor Yellow -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)"
    }
    else { Write-Host "`nGOOD:" -BackgroundColor Green -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)" }

    $results.Tables[0] | Where-Object {$_.state_desc -in 'SUSPECT','RESTORING','RECOVERING','RECOVERY_PENDING','EMERGENCY','OFFLINE','COPYING','OFFLINE_SECONDARY'} | Select-Object database_name,state_desc | Format-Table -AutoSize
} #Get-DatabaseStatus

function Get-AGStatus {
  Param (
    [CmdletBinding()]
    [parameter(Position=0,Mandatory=$true)][ValidateNotNullOrEmpty()]$targetServer
    )

    $server = Get-SqlConnection $targetServer

    $cmd = @"
    SELECT 
	     ag.name AS ag_name
	    ,ar.replica_server_name
	    ,ars.role_desc AS role
	    ,ar.availability_mode_desc
	    ,ar.failover_mode_desc
	    ,adc.[database_name]
	    ,drs.synchronization_state_desc AS synchronization_state
	    ,drs.synchronization_health_desc AS synchronization_health
    FROM sys.dm_hadr_database_replica_states AS drs WITH (NOLOCK)
    INNER JOIN sys.availability_databases_cluster AS adc WITH (NOLOCK) ON drs.group_id = adc.group_id AND drs.group_database_id = adc.group_database_id
    INNER JOIN sys.availability_groups AS ag WITH (NOLOCK) ON ag.group_id = drs.group_id
    INNER JOIN sys.availability_replicas AS ar WITH (NOLOCK) ON drs.group_id = ar.group_id AND drs.replica_id = ar.replica_id
    INNER JOIN sys.dm_hadr_availability_replica_states AS ars ON ar.replica_id = ars.replica_id
    WHERE ars.is_local = 1
    ORDER BY ag.name, ar.replica_server_name, adc.[database_name] OPTION (RECOMPILE);
"@

    #If one exists, get status of each Availability Group
    try {
        $results = $server.ExecuteWithResults($cmd)
    }
    catch {
        Get-Error $_
    }

    #Display the results to the console
    if ($results.Tables[0].Rows.Count -ne 0) {
        if ($results.Tables[0] | Where-Object {$_.synchronization_health -ne 'HEALTHY'}) {
            if ($_.synchronization_health -eq 'NOT_HEALTHY') {
                Write-Host "`nCRITICAL:" -BackgroundColor Red -ForegroundColor White -NoNewline; Write-Host " $($server.TrueName)"
            }
            elseif ($_.synchronization_health -eq 'PARTIALLY_HEALTHY') {
                Write-Host "`nWARNING:" -BackgroundColor Yellow -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)"
            }
        }
        else {
            Write-Host "`nGOOD:" -BackgroundColor Green -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)"
        }

        $results.Tables[0] | Where-Object {$_.synchronization_health -in 'NOT_HEALTHY','PARTIALLY_HEALTHY'} | Select-Object ag_name,role,database_name,synchronization_state,synchronization_health | Format-Table -AutoSize
    }
    else {
      Write-Host "`nGOOD:" -BackgroundColor Green -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)"
      Write-Host '*** No Availabiliy Groups found ***'
    }
} #Get-AGStatus

function Get-DatabaseBackupStatus {
  Param (
    [CmdletBinding()]
    [parameter(Position=0,Mandatory=$true)][ValidateNotNullOrEmpty()]$targetServer
    )

    #Get status of each database
    $server = Get-SqlConnection $targetServer

    $cmd = @"
    SELECT 
	     name AS [database_name]
	    ,recovery_model_desc
	    ,[D] AS last_full_backup
	    ,[I] AS last_differential_backup
	    ,[L] AS last_tlog_backup
	    ,CASE
		    /* These conditions below will cause a CRITICAL status */
		    WHEN [D] IS NULL THEN 'CRITICAL'															-- if last_full_backup is null then critical
		    WHEN [D] < DATEADD(DD,-1,CURRENT_TIMESTAMP) AND [I] IS NULL THEN 'CRITICAL'								-- if last_full_backup is more than 2 days old and last_differential_backup is null then critical
		    WHEN [D] < DATEADD(DD,-7,CURRENT_TIMESTAMP) AND [I] < DATEADD(DD,-2,CURRENT_TIMESTAMP) THEN 'CRITICAL'				-- if last_full_backup is more than 7 days old and last_differential_backup more than 2 days old then critical
		    WHEN recovery_model_desc <> 'SIMPLE' AND name <> 'model' AND [L] IS NULL THEN 'CRITICAL'	-- if recovery_model_desc is SIMPLE and last_tlog_backup is null then critical
		    WHEN recovery_model_desc <> 'SIMPLE' AND name <> 'model' AND [L] < DATEADD(HH,-6,CURRENT_TIMESTAMP) THEN 'CRITICAL'		-- if last_tlog_backup is more than 6 hours old then critical
		    --/* These conditions below will cause a WARNING status */
		    WHEN [D] < DATEADD(DD,-1,CURRENT_TIMESTAMP) AND [I] < DATEADD(DD,-1,CURRENT_TIMESTAMP) THEN 'WARNING'		-- if last_full_backup is more than 1 day old and last_differential_backup is greater than 1 days old then warning
		    WHEN recovery_model_desc <> 'SIMPLE' AND name <> 'model' AND [L] < DATEADD(HH,-3,CURRENT_TIMESTAMP) THEN 'WARNING'		-- if last_tlog_backup is more than 3 hours old then warning
            /* Everything else will return a GOOD status */
		    ELSE 'GOOD'
	     END AS backup_status
	    ,CASE
		    /* These conditions below will cause a CRITICAL status */
		    WHEN [D] IS NULL THEN 'No FULL backups'															-- if last_full_backup is null then critical
		    WHEN [D] < DATEADD(DD,-1,CURRENT_TIMESTAMP) AND [I] IS NULL THEN 'FULL backup > 1 day; no DIFF backups'			-- if last_full_backup is more than 2 days old and last_differential_backup is null then critical
		    WHEN [D] < DATEADD(DD,-7,CURRENT_TIMESTAMP) AND [I] < DATEADD(DD,-2,CURRENT_TIMESTAMP) THEN 'FULL backup > 7 day; DIFF backup > 2 days'	-- if last_full_backup is more than 7 days old and last_differential_backup more than 2 days old then critical
		    WHEN recovery_model_desc <> 'SIMPLE' AND name <> 'model' AND [L] IS NULL THEN 'No LOG backups'	-- if recovery_model_desc is SIMPLE and last_tlog_backup is null then critical
		    WHEN recovery_model_desc <> 'SIMPLE' AND name <> 'model' AND [L] < DATEADD(HH,-6,CURRENT_TIMESTAMP) THEN 'LOG backup > 6 hours'		-- if last_tlog_backup is more than 6 hours old then critical
		    --/* These conditions below will cause a WARNING status */
		    WHEN [D] < DATEADD(DD,-1,CURRENT_TIMESTAMP) AND [I] < DATEADD(DD,-1,CURRENT_TIMESTAMP) THEN 'FULL backup > 7 day; DIFF backup > 1 day'		-- if last_full_backup is more than 1 day old and last_differential_backup is greater than 1 days old then warning
		    WHEN recovery_model_desc <> 'SIMPLE' AND name <> 'model' AND [L] < DATEADD(HH,-3,CURRENT_TIMESTAMP) THEN 'LOG backup > 3 hours'		-- if last_tlog_backup is more than 3 hours old then warning
            /* Everything else will return a GOOD status */
		    ELSE 'No issues'
	     END AS status_desc
    FROM (
	    SELECT
		     d.name
		    ,d.recovery_model_desc
		    ,bs.type
		    ,MAX(bs.backup_finish_date) AS backup_finish_date
	    FROM master.sys.databases d
	    LEFT JOIN msdb.dbo.backupset bs ON d.name = bs.database_name
	    WHERE (bs.type IN ('D','I','L') OR bs.type IS NULL)
	    AND d.database_id <> 2				-- exclude tempdb
	    AND d.source_database_id IS NULL	-- exclude snapshot databases
	    AND d.state NOT IN (1,6,10)			-- exclude offline, restoring, or secondary databases
	    AND d.is_in_standby = 0				-- exclude log shipping secondary databases
	    GROUP BY d.name, d.recovery_model_desc, bs.type
    ) AS SourceTable  
    PIVOT  
    (
	    MAX(backup_finish_date)
	    FOR type IN ([D],[I],[L])  
    ) AS PivotTable
    ORDER BY database_name;
"@
    
    try {
        $results = $server.ExecuteWithResults($cmd)
    }
    catch {
        Get-Error $_
    }

    #Display the results to the console
    if ($results.Tables[0] | Where-Object {$_.backup_status -eq 'CRITICAL'}) {
        Write-Host "`nCRITICAL:" -BackgroundColor Red -ForegroundColor White -NoNewline; Write-Host " $($server.TrueName)"
    }
    elseif ($results.Tables[0] | Where-Object {$_.backup_status -eq 'WARNING'}) {
        Write-Host "`nWARNING:" -BackgroundColor Yellow -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)"
    }
    else {
        Write-Host "`nGOOD:" -BackgroundColor Green -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)"
    }

    $results.Tables[0] | Where-Object {$_.backup_status -in 'CRITICAL','WARNING'} | Select-Object database_name,backup_status,status_desc | Format-Table -AutoSize

} #Get-DatabaseBackupStatus

function Get-DiskSpace {
  Param (
    [CmdletBinding()]
    [parameter(Position=0,Mandatory=$true)][ValidateNotNullOrEmpty()]$targetServer
    )

    $server = Get-SqlConnection $targetServer

    $cmd = @"
    SELECT DISTINCT 
         vs.volume_mount_point
        ,vs.logical_volume_name
        ,CONVERT(DECIMAL(18,2), vs.total_bytes/1073741824.0) AS total_size_gb
        ,CONVERT(DECIMAL(18,2), vs.available_bytes/1073741824.0) AS available_size_gb
        ,CONVERT(DECIMAL(18,2), vs.available_bytes * 1. / vs.total_bytes * 100.) AS free_space_pct
    FROM sys.master_files AS f WITH (NOLOCK)
    CROSS APPLY sys.dm_os_volume_stats(f.database_id, f.[file_id]) AS vs 
    ORDER BY vs.volume_mount_point OPTION (RECOMPILE);
"@

    #Get disk space and store it in the repository
    try {
        $results = $server.ExecuteWithResults($cmd)
    }
    catch {
        Get-Error $_
    }

    #Display the results to the console
    if ($results.Tables[0] | Where-Object {$_.free_space_pct -lt 10.0}) {
        Write-Host "`nCRITICAL:" -BackgroundColor Red -ForegroundColor White -NoNewline; Write-Host " $($server.TrueName)"
    }
    elseif ($results.Tables[0] | Where-Object {$_.free_space_pct -lt 20.0 -and $_.free_space_pct -gt 10.0}) {
        Write-Host "`nWARNING:" -BackgroundColor Yellow -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)"
    }
    else { Write-Host "`nGOOD:" -BackgroundColor Green -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)" }

    $results.Tables[0] | Where-Object {$_.free_space_pct -lt 20.0} | Select-Object volume_mount_point,total_size_gb,available_size_gb,free_space_pct | Format-Table -AutoSize
} #Get-DiskSpace

function Get-FailedJobs {
  Param (
    [CmdletBinding()]
    [parameter(Position=0,Mandatory=$true)][ValidateNotNullOrEmpty()]$targetServer
    )

    $server = Get-SqlConnection $targetServer

    $cmd = @"
    SELECT 
	    j.name AS job_name
	    ,CASE
		    WHEN a.start_execution_date IS NULL THEN 'Not Running'
		    WHEN a.start_execution_date IS NOT NULL AND a.stop_execution_date IS NULL THEN 'Running'
		    WHEN a.start_execution_date IS NOT NULL AND a.stop_execution_date IS NOT NULL THEN 'Not Running'
	        END AS 'current_run_status'
	    ,a.start_execution_date AS 'last_start_date'
	    ,a.stop_execution_date AS 'last_stop_date'
	    ,CASE h.run_status
		    WHEN 0 THEN 'Failed'
		    WHEN 1 THEN 'Succeeded'
		    WHEN 2 THEN 'Retry'
		    WHEN 3 THEN 'Canceled'
	        END AS 'last_run_status'
	    ,h.message AS 'job_output'
    FROM msdb.dbo.sysjobs j
    INNER JOIN msdb.dbo.sysjobactivity a ON j.job_id = a.job_id
    LEFT JOIN msdb.dbo.sysjobhistory h ON a.job_history_id = h.instance_id
    WHERE a.session_id = (SELECT MAX(session_id) FROM msdb.dbo.sysjobactivity)
    ORDER BY j.name;
"@

    #Get the failed jobs and store it in the repository
    try {
        $results = $server.ExecuteWithResults($cmd)
    }
    catch {
        Get-Error $_
    }

    #Display the results to the console
    if ($results.Tables[0] | Where-Object {$_.last_run_status -eq 'Failed'}) {
        Write-Host "`nCRITICAL:" -BackgroundColor Red -ForegroundColor White -NoNewline; Write-Host " $($server.TrueName)"
    }
    elseif ($results.Tables[0] | Where-Object {$_.last_run_status -in 'Retry','Canceled'}) {
        Write-Host "`nWARNING:" -BackgroundColor Yellow -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)"
    }
    else {
      Write-Host "`nGOOD:" -BackgroundColor Green -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)"
    }

    $results.Tables[0] | Where-Object {$_.last_run_status -in 'Failed','Retry','Canceled'} | Select-Object job_name,current_run_status,last_run_status,last_stop_date | Format-Table -AutoSize
} #Get-FailedJobs

function Get-AppLogEvents {
  Param (
    [CmdletBinding()]
    [parameter(Position=0,Mandatory=$true)][ValidateNotNullOrEmpty()]$targetServer
    )

    <#
      NOTE: If SQL is using the "-n" startup paramenter, then SQL does not 
      write to the Windows Application log, and this will always return no errors.
      https://docs.microsoft.com/en-us/sql/database-engine/configure-windows/database-engine-service-startup-options
    #>

    #Get the physical hostname
    $server = Get-SqlConnection $targetServer

    if($server.TrueName.Split('\')[1]) {
        $source = "MSSQL`$$($server.TrueName.Split('\')[1])"
    }
    else {
        $source = 'MSSQLSERVER'
    }

    $cmd = "SELECT SERVERPROPERTY('ComputerNamePhysicalNetBIOS');"
    try {
        $computerName = $server.ExecuteScalar($cmd)
    }
    catch {
        Get-Error $_
    }
    
    #ErrorAction = SilentlyConintue to prevent "No events were found"
    $events = $null
    $events = Get-WinEvent -ComputerName $computerName -FilterHashtable @{LogName='Application';Level=2;StartTime=((Get-Date).AddDays(-1));ProviderName=$source} -ErrorAction SilentlyContinue

    if ($events) {
        #Display the results to the console
        Write-Host "`nCRITICAL:" -BackgroundColor Red -ForegroundColor White -NoNewline; Write-Host " $($server.TrueName)"
        Write-Host "Found $($events.Count) error(s)! Showing only the most recent events:"
        $events | Select-Object TimeCreated,@{Label='EventID';Expression={$_.Id}},Message | Format-Table -AutoSize
    }
    else { Write-Host "`nGOOD:" -BackgroundColor Green -ForegroundColor Black -NoNewline; Write-Host " $($server.TrueName)" }
} #Get-AppLogEvents

####################   MAIN   ########################
Clear-Host

$startTime = Get-Date

[string[]]$targetServerList = $null

#Get the server list from the CMS group, only if one was specified
if($cmsServer) {
    $targetServerList = Get-CmsServer -cmsServer $cmsServer -cmsGroup $cmsGroup -recurse
}
else {
    $targetServerList = $serverList
}

#Check uptime of each SQL Server
Write-Host "##########  SQL Server Uptime Report (DD.HH:MM:SS):  ##########" -BackgroundColor Black -ForegroundColor Green
$targetServerList | ForEach-Object { Get-SqlUptime -targetServer $_}

#Get status of each database for each server
Write-Host "`n##########  Database Status Report:  ##########" -BackgroundColor Black -ForegroundColor Green
$targetServerList | ForEach-Object { Get-DatabaseStatus -targetServer $_}

#Get status of each Availability Group for each server
Write-Host "`n##########  Availability Groups Report:  ##########" -BackgroundColor Black -ForegroundColor Green
$targetServerList | ForEach-Object { Get-AGStatus -targetServer $_}

#Get the most recent backup of each database
Write-Host "`n##########  Database Backup Report:  ##########" -BackgroundColor Black -ForegroundColor Green
$targetServerList | ForEach-Object { Get-DatabaseBackupStatus -targetServer $_}

#Get the disk space info for each server
Write-Host "`n##########  Disk Space Report:  ##########" -BackgroundColor Black -ForegroundColor Green
$targetServerList | ForEach-Object { Get-DiskSpace -targetServer $_}

#Get the failed jobs for each server
Write-Host "`n##########  Failed Jobs Report:  ##########" -BackgroundColor Black -ForegroundColor Green
$targetServerList | ForEach-Object { Get-FailedJobs -targetServer $_}

#Check the Application event log for SQL errors
Write-Host "`n##########  Application Event Log Report:  ##########" -BackgroundColor Black -ForegroundColor Green
$targetServerList | ForEach-Object { Get-AppLogEvents -targetServer $_}

Write-Host "`nElapsed Time: $(New-TimeSpan -Start $startTime -End (Get-Date))"
