[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$installDir = Join-Path $repoRoot ".tools\hugo"
$hugoExe = Join-Path $installDir "hugo.exe"

if (Test-Path $hugoExe) {
    Write-Host "Hugo is already installed at $hugoExe"
    & $hugoExe version
    exit 0
}

$archSuffixMap = @{
    "AMD64" = "windows-amd64.zip"
    "ARM64" = "windows-arm64.zip"
}

$arch = $env:PROCESSOR_ARCHITECTURE.ToUpperInvariant()
if (-not $archSuffixMap.ContainsKey($arch)) {
    throw "Unsupported Windows architecture '$arch'. Please install Hugo Extended manually."
}

$suffix = $archSuffixMap[$arch]
$headers = @{
    "User-Agent" = "isaac0804-site-setup"
    "Accept" = "application/vnd.github+json"
}

Write-Host "Looking up the latest Hugo Extended release for $arch..."
$release = Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/gohugoio/hugo/releases/latest"

$asset = $release.assets |
    Where-Object { $_.name -like "hugo_extended_*_$suffix" } |
    Select-Object -First 1

if (-not $asset) {
    throw "Could not find a Hugo Extended asset for '$suffix' in the latest release."
}

New-Item -ItemType Directory -Path $installDir -Force | Out-Null

$zipPath = Join-Path $env:TEMP $asset.name
Write-Host "Downloading $($asset.name)..."
Invoke-WebRequest -Headers $headers -Uri $asset.browser_download_url -OutFile $zipPath

Write-Host "Extracting Hugo into $installDir..."
Expand-Archive -Path $zipPath -DestinationPath $installDir -Force
Remove-Item $zipPath -Force

Write-Host "Installed Hugo:"
& $hugoExe version
