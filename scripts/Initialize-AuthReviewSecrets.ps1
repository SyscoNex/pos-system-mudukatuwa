param()
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$secretRoot = Join-Path $repoRoot '.local/auth-review'
New-Item -ItemType Directory -Force $secretRoot | Out-Null
function New-Secret([string]$Name) {
    $path = Join-Path $secretRoot $Name
    if (!(Test-Path -LiteralPath $path)) {
        $bytes = [System.Security.Cryptography.RandomNumberGenerator]::GetBytes(48)
        [IO.File]::WriteAllText($path, [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+','-').Replace('/','_'))
    }
}
foreach ($name in @('mysql-root-password','mysql-migration-password','mysql-runtime-password','dp-password')) { New-Secret $name }
foreach ($kind in @('runtime','migration')) {
    $password = [IO.File]::ReadAllText((Join-Path $secretRoot "mysql-$kind-password"))
    [IO.File]::WriteAllText((Join-Path $secretRoot "$kind-connection"), "Server=mysql;Database=conex360_auth_review;User ID=conex_$kind;Password=$password;SSL Mode=Required;")
}
$certPath = Join-Path $secretRoot 'data-protection.pfx'
if (!(Test-Path -LiteralPath $certPath)) {
    $rsa = [Security.Cryptography.RSA]::Create(3072)
    $request = [Security.Cryptography.X509Certificates.CertificateRequest]::new('CN=Conex360 isolated development key protection', $rsa, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
    $certificate = $request.CreateSelfSigned([DateTimeOffset]::UtcNow.AddDays(-1), [DateTimeOffset]::UtcNow.AddYears(1))
    [IO.File]::WriteAllBytes($certPath, $certificate.Export([Security.Cryptography.X509Certificates.X509ContentType]::Pfx, [IO.File]::ReadAllText((Join-Path $secretRoot 'dp-password'))))
    $certificate.Dispose()
    $rsa.Dispose()
}
Write-Output 'Prepared ignored local secret files. No database was started. Protect this directory with your workstation account permissions.'
