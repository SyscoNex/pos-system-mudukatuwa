# Synthetic data only, in the separately approved auth-review database.
$ErrorActionPreference='Stop'
$repoRoot=Split-Path $PSScriptRoot -Parent
$evidence=Join-Path $repoRoot 'artifacts/auth-review'
New-Item -ItemType Directory -Force $evidence | Out-Null
$suffix=[Guid]::NewGuid().ToString('N')
$password=[Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
$inputData=@{operationId=[Guid]::NewGuid();tenantCode="browser-$suffix";businessName='Synthetic Browser Coconut Business';displayName='Coconut Studio';administratorEmail="$suffix@example.invalid";administratorName='Synthetic Administrator';timezone='Asia/Colombo';currencyCode='LKR';currencyMinorUnits=2;operatorReference='synthetic-browser-fixture';reason='Approved isolated P1-02 browser acceptance'}
[IO.File]::WriteAllText((Join-Path $evidence 'forced-provisioning.json'),($inputData|ConvertTo-Json))
Push-Location $repoRoot
try {
    $password | docker compose -p conex360-auth-review -f infrastructure/compose.auth-review.yaml -f infrastructure/compose.workbench.yaml --profile database-approved run -T --rm --pull never tools backend/src/Conex360.Api/bin/Release/net10.0/Conex360.Api.dll --admin-provision --input /evidence/forced-provisioning.json --password-stdin
    if($LASTEXITCODE -ne 0){throw 'Synthetic controlled provisioning failed.'}
    [IO.File]::WriteAllText((Join-Path $evidence 'browser-forced-fixture.json'),(@{email=$inputData.administratorEmail;password=$password}|ConvertTo-Json))
} finally {Pop-Location; $password=$null}
