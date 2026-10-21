[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$EvidenceDirectory,
    [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ReviewedSha256,
    [string]$BuildTools = 'C:\Users\hp\AppData\Local\Android\Sdk\build-tools\36.0.0'
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$release = Get-Content -Raw (Join-Path $repo 'src/data/helper-release.json') | ConvertFrom-Json
if ($null -eq $release -or $release.sha256 -ne $ReviewedSha256.ToLowerInvariant()) { throw 'No exact approved signed release is staged' }
New-Item -ItemType Directory -Force -Path $EvidenceDirectory | Out-Null
$pageUrl = 'https://www.monkeycoding.com/aivox/helper'
$page = Invoke-WebRequest -Uri $pageUrl -UseBasicParsing
if ($page.StatusCode -ne 200 -or $page.Content -notmatch [regex]::Escape($release.path) -or
    $page.Content -notmatch [regex]::Escape($release.sha256) -or $page.Content -notmatch [regex]::Escape($release.certificateSha256)) { throw 'Original Free landing URL does not offer exact release receipt and path' }
$page.Content | Set-Content -Encoding utf8 (Join-Path $EvidenceDirectory 'public-helper-page.html')
$url = 'https://www.monkeycoding.com' + $release.path
$download = Join-Path $EvidenceDirectory 'downloaded-Helper-release.apk'
if (Test-Path -LiteralPath $download) { throw 'Use a fresh evidence directory; do not overwrite earlier download proof' }
$response = Invoke-WebRequest -Uri $url -MaximumRedirection 0 -UseBasicParsing -OutFile $download -PassThru
if ($response.StatusCode -ne 200 -or
    (($response.Headers['Content-Type'] -join '') -notmatch 'application/vnd.android.package-archive' -and
     ($response.Headers['Content-Disposition'] -join '') -notmatch 'attachment')) { throw 'Wrong HTTP status or binary headers' }
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $download).Hash.ToLowerInvariant()
if ($hash -ne $release.sha256 -or (Get-Item $download).Length -ne $release.sizeBytes) { throw 'Public bytes mismatch or stale CDN' }
$signature = & (Join-Path $BuildTools 'apksigner.bat') verify --verbose --print-certs --min-sdk-version 21 $download 2>&1
if ($LASTEXITCODE -ne 0 -or ($signature -join "`n") -notmatch "Signer #1 certificate SHA-256 digest: $($release.certificateSha256)" -or
    ($signature -join "`n") -notmatch 'Number of signers: 1') { throw 'Public APK signature mismatch' }
$signature | Set-Content -Encoding utf8 (Join-Path $EvidenceDirectory 'public-downloaded-signature.txt')
@{status='DOWNLOAD_PASS'; landingUrl=$pageUrl; binaryUrl=$url; sha256=$hash; bytes=$release.sizeBytes;
  certificateSha256=$release.certificateSha256; headers=$response.Headers; verifiedUtc=[DateTime]::UtcNow.ToString('o');
  device='OWNER_DEVICE_TEST_PENDING'
} | ConvertTo-Json -Depth 8 | Set-Content -Encoding utf8 (Join-Path $EvidenceDirectory 'public-download-receipt.json')
Write-Host 'DOWNLOAD_PASS: original landing page, HTTP 200, exact bytes and Helper release certificate verified. No device acceptance implied.'
