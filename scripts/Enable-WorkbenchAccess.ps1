param()
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$secretRoot = Join-Path $repoRoot '.local/auth-review'
$passwordPath = Join-Path $secretRoot 'mysql-workbench-password'
$composeArgs = @('compose', '-p', 'conex360-auth-review', '-f', (Join-Path $repoRoot 'infrastructure/compose.auth-review.yaml'), '-f', (Join-Path $repoRoot 'infrastructure/compose.workbench.yaml'), '--profile', 'database-approved')

# Only resume an existing initialized review database. Never initialize/migrate here.
$containerId = & docker @composeArgs ps -q mysql
if ($LASTEXITCODE -ne 0 -or !$containerId) { throw 'Start the existing initialized conex360-auth-review MySQL service first.' }
$checkTarget = 'MYSQL_PWD="$(cat /run/secrets/mysql_root_password)" mysql --protocol=socket -u root -N -B --execute="SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=''conex360_auth_review'' AND table_name=''schema_migrations'';"'
$journalCount = & docker exec $containerId sh -c $checkTarget
if ($LASTEXITCODE -ne 0 -or "$journalCount".Trim() -ne '1') { throw 'Expected initialized review database not found; stopped without changes.' }

if (!(Test-Path -LiteralPath $passwordPath)) {
    $bytes = [Security.Cryptography.RandomNumberGenerator]::GetBytes(48)
    [IO.File]::WriteAllText($passwordPath, [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_'))
}
$readerPassword = [IO.File]::ReadAllText($passwordPath)
if ($readerPassword -cnotmatch '^[A-Za-z0-9_-]{32,128}$') { throw 'Unexpected inspection password format.' }

# Recreate only this service, preserving its existing named volume and secrets.
& docker @composeArgs up -d --no-deps --wait --wait-timeout 60 mysql
if ($LASTEXITCODE -ne 0) { throw 'Could not publish the local inspection port; check whether 3307 is in use.' }

# Password travels through stdin, never through arguments or output.
$sql = @"
CREATE USER IF NOT EXISTS 'conex_workbench'@'%' IDENTIFIED BY '$readerPassword' REQUIRE SSL;
ALTER USER 'conex_workbench'@'%' IDENTIFIED BY '$readerPassword' REQUIRE SSL;
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'conex_workbench'@'%';
GRANT SELECT, SHOW VIEW ON conex360_auth_review.* TO 'conex_workbench'@'%';
"@
try {
    $sql | & docker @composeArgs exec -T mysql sh -c 'MYSQL_PWD="$(cat /run/secrets/mysql_root_password)" exec mysql --protocol=socket --user=root'
    if ($LASTEXITCODE -ne 0) { throw 'Could not configure the inspection account.' }
} finally {
    $readerPassword = $null
    $sql = $null
}
Write-Output 'Workbench: Standard TCP/IP, 127.0.0.1:3307, user conex_workbench, schema conex360_auth_review, SSL Require.'
Write-Output "Password is stored only in $passwordPath. The account has SELECT/SHOW VIEW access only."
