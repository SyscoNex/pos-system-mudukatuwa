$ErrorActionPreference='Stop'
$repoRoot=Split-Path $PSScriptRoot -Parent
$composeArgs=@('compose','-p','conex360-auth-review','-f','infrastructure/compose.auth-review.yaml','--profile','database-approved','--profile','runtime')
function Assert-Http([string]$Path,[int]$Expected) {
    $response=Invoke-WebRequest "http://127.0.0.1:5182$Path" -SkipHttpErrorCheck -TimeoutSec 15
    if([int]$response.StatusCode -ne $Expected){throw "Unexpected $Path status: $($response.StatusCode), expected $Expected"}
}
function Wait-Ready {
    for($attempt=0;$attempt -lt 30;$attempt++) {
        try {Assert-Http '/health/ready' 200;return} catch {Start-Sleep -Seconds 1}
    }
    throw 'Review API readiness timed out.'
}
function Check-Private([string]$Mode='') {
    Push-Location (Join-Path $repoRoot 'frontend')
    try {node scripts/check-auth-persistence.mjs $Mode; if($LASTEXITCODE -ne 0){throw 'Private session/logo check failed.'}} finally {Pop-Location}
}
Push-Location $repoRoot
try {
    . ./scripts/Use-LocalNode.ps1
    Wait-Ready
    Check-Private '--record'
    & docker @composeArgs stop mysql
    if($LASTEXITCODE -ne 0){throw 'Review MySQL stop failed.'}
    try {
        Assert-Http '/health/live' 200
        Assert-Http '/health/ready' 503
        Check-Private '--database-unavailable'
    } finally {
        & docker @composeArgs up -d --wait mysql
        if($LASTEXITCODE -ne 0){throw 'Review MySQL recovery failed.'}
    }
    Wait-Ready
    Check-Private
    & docker @composeArgs restart api
    if($LASTEXITCODE -ne 0){throw 'Review API restart failed.'}
    Wait-Ready
    Check-Private
    & docker @composeArgs exec -T api sh -c 'grep -q encryptedSecret /data/keys/key-*.xml'
    if($LASTEXITCODE -ne 0){throw 'Persistent key ring encryption was not verified.'}
    Write-Output 'PASS: liveness/readiness dependency failure, MySQL recovery, API restart, session/logo persistence and encrypted key ring.'
} finally {Pop-Location}
