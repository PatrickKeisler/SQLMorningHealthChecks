# SQLMorningHealthChecks

Supported On-prem Versions: SQL Server 2012 and higher

This script answers the following questions about your SQL Servers.

1. What is the uptime of each SQL Server?
   1. CRITICAL = < 6 hours
   2. WARNING  = > 6 hours and < 24 hours
   3. GOOD     = > 24 hours
2. What is the status of each SQL service (engine, agent, full text, etc)?
   1. CRITICAL = Not running with automatic startup
   2. GOOD     = Running
3. What is the status of each cluster node (AG or FCI)?
   1. CRITICAL = Down
   2. GOOD     = Up
4. What is the status of each database?
   1. CRITICAL = Suspect
   2. WARNING  = Restoring, recovering, recoery_pending, emergency, offline, copying, or offline_secondary
   3. GOOD     = Normal
5. What is the status of each Availability Group?
   1. CRITICAL = Not_healthy
   2. WARNING  = Partially_healthy
   3. GOOD     = Healthy
6. What is the backup status of each database?
   1. CRITICAL = No FULL/DIFF/LOG, FULL > 7 days and DIFF > 2 days, LOG > 6 hours
   2. WARNING  = FULL > 7 days and DIFF > 1 day, LOG > 3 hours
   3. GOOD     = Normal
7. What is the available disk space?
   1. CRITICAL = < 10%
   2. WARNING  = > 10% and < 20%
   3. GOOD     = > 20%
8. Are there any SQL Agent failed jobs in the last 24 hours?
   1. CRITICAL = Failed
   2. WARNING  = Retry or Canceled
   3. GOOD     = Succeeded
9. What errors appeared in the SQL errorlog in the last 24 hours?
   1. CRITICAL = Errors logged
   2. GOOD     = No errors logged

For a full description of how this script works, read the article here.

https://docs.microsoft.com/en-us/archive/blogs/samlester/sql-server-dba-morning-health-checks
