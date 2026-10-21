[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SignedApk,
    [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ReviewedSha256,
    [string]$BuildTools = 'C:\Users\hp\AppData\Local\Android\Sdk\build-tools\36.0.0'
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$pin = '81b0270e9b0546f146d2446e917607acf3efa3edd5e9071199fea391db575fa6'
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $SignedApk).Hash.ToLowerInvariant()
if ($hash -ne $ReviewedSha256.ToLowerInvariant()) { throw 'APK differs from reviewed exact hash' }
$signature = & (Join-Path $BuildTools 'apksigner.bat') verify --verbose --print-certs --min-sdk-version 21 $SignedApk 2>&1
if ($LASTEXITCODE -ne 0) { throw 'Unsigned or invalid APK; download remains unavailable' }
$sig = $signature -join "`n"
if ($sig -notmatch "Signer #1 certificate SHA-256 digest: $pin" -or $sig -notmatch 'Number of signers: 1' -or
    $sig -notmatch 'Verified using v1 scheme.*true' -or $sig -notmatch 'Verified using v2 scheme.*true' -or
    $sig -notmatch 'Verified using v3 scheme.*true') { throw 'Wrong signer or signature schemes' }
$badging = & (Join-Path $BuildTools 'aapt.exe') dump badging $SignedApk
if ($LASTEXITCODE -ne 0) { throw 'Invalid APK' }
$metadata = $badging -join "`n"
if ($metadata -notmatch "package: name='com\.monkeycoding\.aivox\.helper' versionCode='4' versionName='3\.0\.0'" -or
    $metadata -notmatch "sdkVersion:'21'" -or $metadata -notmatch "targetSdkVersion:'36'" -or
    $metadata -match 'application-debuggable' -or $metadata -match 'android.permission.INTERNET') { throw 'Wrong Helper metadata' }
$path = "/downloads/aivox-helper/3.0.0-4/Aivox-Helper-3.0.0-4-$hash.apk"
$destination = Join-Path $repo "public$path"
if (Test-Path -LiteralPath $destination) { throw 'Immutable destination already exists; do not overwrite' }
New-Item -ItemType Directory -Force -Path (Split-Path $destination) | Out-Null
Copy-Item -LiteralPath $SignedApk -Destination $destination
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $destination).Hash.ToLowerInvariant() -ne $hash) { throw 'Copy hash mismatch' }
@{package='com.monkeycoding.aivox.helper'; versionCode=4; versionName='3.0.0'; minSdk=21; targetSdk=36;
  certificateSha256=$pin; sha256=$hash; sizeBytes=(Get-Item -LiteralPath $destination).Length; path=$path
} | ConvertTo-Json | ForEach-Object {
    [IO.File]::WriteAllText((Join-Path $repo 'src/data/helper-release.json'), $_, [Text.UTF8Encoding]::new($false))
}
Push-Location $repo
try {
    & npm run build
    if ($LASTEXITCODE -ne 0) { throw 'Site validation failed; do not publish' }
} finally { Pop-Location }
Write-Host "Staged locally only: https://www.monkeycoding.com$path"
Write-Host 'PUBLIC_DOWNLOAD_PENDING_OWNER_DEPLOY: exact-hash owner approval is required before production publication.'
