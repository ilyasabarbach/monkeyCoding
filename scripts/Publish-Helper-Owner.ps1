[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ReviewedSha256,
    [Parameter(Mandatory)][switch]$OwnerApprovesExactHashAndProductionScope,
    [Parameter(Mandatory)][string]$EvidenceDirectory
)
$ErrorActionPreference = 'Stop'
if (!$OwnerApprovesExactHashAndProductionScope) { throw 'Explicit approval of exact signed Helper hash, certificate and production site scope is required' }
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $repo
try {
    $release = Get-Content -Raw src/data/helper-release.json | ConvertFrom-Json
    if ($null -eq $release -or $release.sha256 -ne $ReviewedSha256.ToLowerInvariant() -or
        $release.certificateSha256 -ne '81b0270e9b0546f146d2446e917607acf3efa3edd5e9071199fea391db575fa6') { throw 'No matching reviewed release' }
    if ((& git branch --show-current) -ne 'feat/aivox-helper-final-download-mon09') { throw 'Wrong site branch' }
    $remoteMain = & git ls-remote origin refs/heads/main
    if ($LASTEXITCODE -ne 0 -or $remoteMain -notmatch '^cf465ed184d8e6a6bfd171737b078482593d6203\s') { throw 'Website main diverged; reconcile before publication' }
    $apk = Join-Path $repo "public$($release.path)"
    $signature = & 'C:\Users\hp\AppData\Local\Android\Sdk\build-tools\36.0.0\apksigner.bat' verify --verbose --print-certs --min-sdk-version 21 $apk 2>&1
    if ($LASTEXITCODE -ne 0 -or ($signature -join "`n") -notmatch "Signer #1 certificate SHA-256 digest: $($release.certificateSha256)") { throw 'Release signature invalid' }
    & npm run build
    if ($LASTEXITCODE -ne 0) { throw 'Website build failed' }
    New-Item -ItemType Directory -Force .vercel | Out-Null
    [IO.File]::WriteAllText((Join-Path $repo '.vercel/project.json'), '{"projectId":"prj_oM003F7UULi2BxAwGUGwIbzRlOyG","orgId":"team_0PPZZZyHrqnOu3KbxD1mtlM3","projectName":"monkey-coding"}', [Text.UTF8Encoding]::new($false))
    # Existing owner Vercel login only. No tokens, DNS changes, merges or main pushes.
    & npx --yes vercel@64.7.0 deploy --prod --yes --scope team_0PPZZZyHrqnOu3KbxD1mtlM3
    if ($LASTEXITCODE -ne 0) { throw 'Publication failed; DOWNLOAD_PASS not established' }
    & (Join-Path $PSScriptRoot 'Verify-PublicDownload.ps1') -EvidenceDirectory $EvidenceDirectory -ReviewedSha256 $ReviewedSha256
} finally { Pop-Location }
