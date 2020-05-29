# SQLMorningHealthChecks

Supported On-prem Versions: SQL Server 2012 and higher

This script answers the following questions about your SQL Servers.

1. What is the uptime of each SQL Server?
   A. CRITICAL = < 6 hours
   B. WARNING  = > 6 hours and < 24 hours
   C. GOOD     = > 24 hours
2. What is the status of each SQL service (engine, agent, full text, etc)?
   A. CRITICAL = Not running with automatic startup
   B. GOOD     = Running
3. What is the status of each cluster node (AG or FCI)?
   A. CRITICAL = Down
   B. GOOD     = Up
4. What is the status of each database?
   A. CRITICAL = Suspect
   B. WARNING  = Restoring, recovering, recoery_pending, emergency, offline, copying, or offline_secondary
   C. GOOD     = Normal
5. What is the status of each Availability Group?
   A. CRITICAL = Not_healthy
   B. WARNING  = Partially_healthy
   C. GOOD     = Healthy
6. What is the backup status of each database?
   A. CRITICAL = No FULL/DIFF/LOG, FULL > 7 days and DIFF > 2 days, LOG > 6 hours
   B. WARNING  = FULL > 7 days and DIFF > 1 day, LOG > 3 hours
   C. GOOD     = Normal
7. What is the available disk space?
   A. CRITICAL = < 10%
   B. WARNING  = > 10% and < 20%
   C. GOOD     = > 20%
8. Are there any SQL Agent failed jobs in the last 24 hours?
   A. CRITICAL = Failed
   B. WARNING  = Retry or Canceled
   C. GOOD     = Succeeded
9. What errors appeared in the SQL errorlog in the last 24 hours?
   A. CRITICAL = Errors logged
   B. GOOD     = No errors logged

For a full description of how this script works, read the article here.

https://docs.microsoft.com/en-us/archive/blogs/samlester/sql-server-dba-morning-health-checks
