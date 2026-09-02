#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$install = Join-Path $root "install.ps1"
$readme = Join-Path $root "README.md"
$security = Join-Path $root "docs\security.md"

$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($install, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) {
  $errors | ForEach-Object { Write-Error $_.Message }
  throw "install.ps1 has PowerShell parse errors."
}

$combined = [IO.File]::ReadAllText($install) + [IO.File]::ReadAllText($readme) + [IO.File]::ReadAllText($security)
$forbiddenLiterals = @(
  "Authorization = `"Bearer "
)
foreach ($item in $forbiddenLiterals) {
  if ($combined.Contains($item)) {
    throw ("Forbidden literal found: " + $item)
  }
}

$secretPatterns = @(
  "Bearer\s+[A-Za-z0-9_-]{24,}",
  "[A-Za-z0-9]{32,}:[A-Za-z0-9_-]{24,}",
  "https?://\d{1,3}(\.\d{1,3}){3}"
)
foreach ($pattern in $secretPatterns) {
  if ([regex]::IsMatch($combined, $pattern)) {
    throw ("Forbidden secret-like pattern found: " + $pattern)
  }
}

if (-not $combined.Contains("https://mcp.dep1c.com/connect")) {
  throw "Expected connect root is absent."
}

if (-not $combined.Contains("ExecutionPolicy Bypass")) {
  throw "ExecutionPolicy Bypass process-local guidance is absent."
}

Write-Output "CHECK=OK"
