[CmdletBinding()]
param(
    [int]$Port = 1313,
    [string]$Bind = "127.0.0.1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$hugoExe = Join-Path $repoRoot ".tools\hugo\hugo.exe"
$setupScript = Join-Path $PSScriptRoot "setup-hugo.ps1"

if (-not (Test-Path $hugoExe)) {
    & $setupScript
}

Push-Location $repoRoot
try {
    & $hugoExe server --buildDrafts --disableFastRender --bind $Bind --port $Port
}
finally {
    Pop-Location
}
