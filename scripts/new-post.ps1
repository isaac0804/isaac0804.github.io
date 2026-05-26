[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Title
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$hugoExe = Join-Path $repoRoot ".tools\hugo\hugo.exe"
$setupScript = Join-Path $PSScriptRoot "setup-hugo.ps1"

if (-not (Test-Path $hugoExe)) {
    & $setupScript
}

$titleText = ($Title -join " ").Trim()
if ([string]::IsNullOrWhiteSpace($titleText)) {
    throw "Title cannot be empty."
}

$slug = $titleText.ToLowerInvariant()
$slug = $slug -replace "[^a-z0-9]+", "-"
$slug = $slug.Trim("-")

if ([string]::IsNullOrWhiteSpace($slug)) {
    throw "Could not generate a valid slug from title '$titleText'."
}

$datePrefix = Get-Date -Format "yyyy-MM-dd"
$relativePath = "content/posts/$datePrefix-$slug.md"
$fullPath = Join-Path $repoRoot $relativePath

Push-Location $repoRoot
try {
    & $hugoExe new $relativePath
}
finally {
    Pop-Location
}

$escapedTitle = $titleText.Replace('"', '\"')
$content = Get-Content -Raw $fullPath
$updated = [regex]::Replace($content, '(?m)^title:\s*".*"$', ('title: "{0}"' -f $escapedTitle), 1)
Set-Content -Path $fullPath -Value $updated -NoNewline

Write-Host "Created draft post at $relativePath"
