# Local MySQL Workbench access

SchoolGrid uses the separate Docker project `database`, including `database-percona-server-1` on host port 3306. Do not start, stop, recreate or reconfigure that project for Conex360 work. Conex360 inspection uses only `conex360-auth-review` and localhost port 3307.

Owner requested Workbench access on 28 November 2026. This optional override publishes only the existing review MySQL service at 127.0.0.1:3307. The default Compose file still has no published MySQL port. No application schema/migration, production target or stock/cost behavior changes.

From the repository root in PowerShell, with the initialized review MySQL container running:

```powershell
.\scripts\Enable-WorkbenchAccess.ps1
```

The script recreates only review MySQL with its existing volume (brief database interruption), and creates/reconciles the dedicated `conex_workbench` account. It requires SSL and grants only SELECT/SHOW VIEW on `conex360_auth_review`. The random password persists in ignored `.local/auth-review/mysql-workbench-password`; it is never printed or passed in command arguments. Re-running the script retains that password.

In Workbench click **+** beside MySQL Connections and enter:

| Field | Value |
|---|---|
| Connection Name | Conex360 Local Review |
| Connection Method | Standard (TCP/IP) |
| Hostname | 127.0.0.1 |
| Port | 3307 |
| Username | conex_workbench |
| Default Schema | conex360_auth_review |
| SSL / Use SSL | Require |

Copy the password locally without displaying it:

```powershell
Get-Content .local/auth-review/mysql-workbench-password -Raw | Set-Clipboard
```

Paste into Workbench's password prompt or **Store in Vault**, then **Test Connection** and save. This local review server uses a development certificate, so use Require, not Verify CA/Identity. Production certificate requirements remain unchanged.

Open the saved connection. In the **Schemas** panel refresh, expand **conex360_auth_review > Tables**, then right-click a table and choose **Select Rows - Limit 1000**. Table Inspector shows columns, indexes and foreign keys. The account sees this project's database and permitted MySQL metadata, not other application databases. Account creation, table/schema edits and row writes are intentionally unavailable through this inspection account.

```sql
SHOW TABLES FROM conex360_auth_review;
SHOW CREATE TABLE conex360_auth_review.companies;
SELECT * FROM conex360_auth_review.companies LIMIT 20;
```

Include both Compose files whenever recreating review MySQL to retain the mapping:

```powershell
docker compose -p conex360-auth-review -f infrastructure/compose.auth-review.yaml -f infrastructure/compose.workbench.yaml --profile database-approved up -d --no-deps --wait mysql
```

Also include both files when running provisioning/tools commands, because Compose may reconcile their MySQL dependency using the base configuration and remove the optional mapping. Example:

```powershell
docker compose -p conex360-auth-review -f infrastructure/compose.auth-review.yaml -f infrastructure/compose.workbench.yaml --profile database-approved run --rm tools backend/src/Conex360.Api/bin/Release/net10.0/Conex360.Api.dll --admin-provision --input /evidence/new-business.json
```

If the port disappears after using a base-only command, rerun `scripts/Enable-WorkbenchAccess.ps1`; it preserves the existing review database and password. On 28 November 2026 this mapping was restored and Workbench's TCP client verified required TLS, all eight tables and SELECT/SHOW VIEW grants; API readiness recovered to 200. SchoolGrid remained stopped with its original container and port binding.

To remove the host port while preserving the database/inspection account, recreate just MySQL with the base file:

```powershell
docker compose -p conex360-auth-review -f infrastructure/compose.auth-review.yaml --profile database-approved up -d --no-deps --wait mysql
```

Official Workbench guidance: [TCP/IP and SSL settings](https://dev.mysql.com/doc/workbench/en/wb-mysql-connections-methods-standard.html), [view table rows](https://dev.mysql.com/doc/workbench/en/workbench-faq.html).

Verified locally on 28 November 2026: existing review volume retained; Windows Workbench-bundled mysql.exe connected to 127.0.0.1:3307 with this account and required TLS (TLS_AES_256_GCM_SHA384), listed all eight tables, and showed only SELECT/SHOW VIEW schema grants. A zero-row DELETE was denied with MySQL error 1142. Backend readiness was healthy after recreation. An initial attempt to use the API's MySqlConnector assembly directly inside PowerShell failed during logging initialization; the successful connection check used Workbench's own client. No application schema/migration or data changed; the account/grants and optional host mapping are the only database-access changes. The Workbench GUI connection itself must still be saved using the settings above.
