param([switch] $Install)
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$nodeVersion = '26.13.1'
$toolsDirectory = Join-Path $repositoryRoot '.tools'
$runtimeDirectory = Join-Path $toolsDirectory "node-v$nodeVersion-win-x64"
$nodeExecutable = Join-Path $runtimeDirectory 'node.exe'

if (-not (Test-Path -LiteralPath $nodeExecutable)) {
    if (-not $Install) {
        throw 'Workspace Node is missing. Dot-source this script with -Install, or use the pinned Node version yourself.'
    }
    New-Item -ItemType Directory -Force -Path $toolsDirectory | Out-Null
    $archiveName = "node-v$nodeVersion-win-x64.zip"
    $archivePath = Join-Path $toolsDirectory $archiveName
    $releaseUrl = "https://nodejs.org/dist/v$nodeVersion"
    $checksums = (Invoke-WebRequest -Uri "$releaseUrl/SHASUMS256.txt").Content
    $checksumLine = ($checksums -split "`n" | Where-Object { $_.Trim().EndsWith("  $archiveName") })
    if (@($checksumLine).Count -ne 1) { throw 'Cannot identify the official Node checksum.' }
    $expectedHash = ($checksumLine.Trim() -split '\s+')[0]
    Invoke-WebRequest -Uri "$releaseUrl/$archiveName" -OutFile $archivePath
    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $archivePath).Hash
    if ($actualHash -ne $expectedHash) { throw 'Node archive checksum mismatch; runtime was not extracted.' }
    Expand-Archive -LiteralPath $archivePath -DestinationPath $toolsDirectory
}

if ((& $nodeExecutable --version) -ne "v$nodeVersion") { throw 'Unexpected workspace Node version.' }
$env:PATH = "$runtimeDirectory;$env:PATH"
$env:PLAYWRIGHT_BROWSERS_PATH = Join-Path $toolsDirectory 'playwright'
Write-Output "Using workspace Node v$nodeVersion (this shell only)."
