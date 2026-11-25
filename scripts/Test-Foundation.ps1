#Requires -Version 7.0
param([uri] $Origin = 'http://127.0.0.1:3600')
$ErrorActionPreference = 'Stop'
if ($Origin.Scheme -notin @('http', 'https') -or -not $Origin.IsLoopback -or $Origin.AbsolutePath -ne '/' -or $Origin.Query -or $Origin.Fragment) {
    throw 'Foundation smoke checks accept a loopback origin only; never point them at production.'
}
$baseUrl = $Origin.GetLeftPart([UriPartial]::Authority)

function Read-JsonResponse($Response) {
    # PowerShell may expose application/problem+json as bytes, unlike application/json.
    $payload = if ($Response.Content -is [byte[]]) {
        [Text.Encoding]::UTF8.GetString($Response.Content)
    } else { [string] $Response.Content }
    ConvertFrom-Json -InputObject $payload
}

$page = Invoke-WebRequest -Uri "$baseUrl/" -TimeoutSec 10
if ($page.StatusCode -ne 200 -or $page.Content -notmatch 'Conex360' -or $page.Headers['Cache-Control'] -notmatch 'no-store') {
    throw 'Workspace page or private cache policy failed.'
}
$health = Invoke-WebRequest -Uri "$baseUrl/api/v1/health" -TimeoutSec 10
$healthBody = Read-JsonResponse $health
if ($health.StatusCode -ne 200 -or $healthBody.service -ne 'conex360-api' -or $healthBody.status -ne 'healthy' -or $healthBody.scope -ne 'process' -or $health.Headers['Cache-Control'] -notmatch 'no-store') {
    throw 'API routing/process-health contract failed.'
}
$assetPath = [regex]::Match($page.Content, 'src="(/_next/static/[^\"]+)"').Groups[1].Value
if (-not $assetPath) { throw 'Built JavaScript asset is missing from the page.' }
$asset = Invoke-WebRequest -Uri ($baseUrl + $assetPath) -TimeoutSec 10
$favicon = Invoke-WebRequest -Uri "$baseUrl/favicon.svg" -TimeoutSec 10
$missing = Invoke-WebRequest -Uri "$baseUrl/api/v1/not-a-module" -SkipHttpErrorCheck -TimeoutSec 10
$problem = Read-JsonResponse $missing
if ($missing.StatusCode -ne 404 -or $problem.code -ne 'NOT_FOUND' -or -not $problem.traceId) {
    throw 'API problem-details routing failed.'
}
[pscustomobject]@{
    Page = $page.StatusCode
    PrivateCache = $page.Headers['Cache-Control'] -join ', '
    Api = $health.StatusCode
    HealthScope = $healthBody.scope
    BuiltAsset = $asset.StatusCode
    Favicon = $favicon.StatusCode
    UnknownApiRoute = $missing.StatusCode
    ProblemCode = $problem.code
}
