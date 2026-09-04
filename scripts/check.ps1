#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$install = Join-Path $root "install.ps1"
$readme = Join-Path $root "README.md"
$agentInstall = Join-Path $root "AGENT-INSTALL.md"
$agents = Join-Path $root "AGENTS.md"
$agentPrompt = Join-Path $root "docs\agent-prompt.md"
$security = Join-Path $root "docs\security.md"
$troubleshooting = Join-Path $root "docs\troubleshooting.md"

$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($install, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) {
  $errors | ForEach-Object { Write-Error $_.Message }
  throw "install.ps1 has PowerShell parse errors."
}

$combined = [IO.File]::ReadAllText($install) + [IO.File]::ReadAllText($readme) + [IO.File]::ReadAllText($agentInstall) + [IO.File]::ReadAllText($agents) + [IO.File]::ReadAllText($agentPrompt) + [IO.File]::ReadAllText($security) + [IO.File]::ReadAllText($troubleshooting)
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

if (-not $combined.Contains("powershell.exe -NoProfile -ExecutionPolicy Bypass -File `$p")) {
  throw "ExecutionPolicy Bypass -File launcher command is absent."
}

$expectedPrompt = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("0J/QvtC00LrQu9GO0YfQuCDQv9C10YHQvtGH0L3QuNGG0YMgRGVwU2FuZGJveCAoaHR0cHM6Ly9naXRodWIuY29tL0tPUlVTLUNvbnN1bHRpbmctR0stTExDL0RTQi1zdGFydCkg0Log0YLQtdC60YPRidC10LzRgyDQv9GA0L7QtdC60YLRgy4g0KLQvtC60LXQvSDQu9C10LbQuNGCINCyINGE0LDQudC70LUg0LIg0LrQvtGA0L3QtSDQv9GA0L7QtdC60YLQsC4="))
if (-not $combined.Contains($expectedPrompt)) {
  throw "Expected natural-language token-file prompt is absent."
}

if (-not $combined.Contains("Unblock-File -LiteralPath `$p")) {
  throw "Unblock-File guidance is absent."
}

if (-not $combined.Contains("native\git\cmd")) {
  throw "Codex bundled Git path is absent."
}

if (-not $combined.Contains("READY_FOR_TOKEN")) {
  throw "Terminal readiness marker is absent."
}

if (-not $combined.Contains("-TokenFile")) {
  throw "Token file flow is absent."
}

if (-not $combined.Contains("-RemoveTokenFileAfterRead")) {
  throw "One-time token file cleanup option is absent."
}

if (-not $combined.Contains("-KeepRunArtifacts")) {
  throw "Run artifact debug option is absent."
}

if (-not $combined.Contains("DEPSANDBOX_DOMAIN_UNAVAILABLE")) {
  throw "Domain-unavailable diagnostic marker is absent."
}

if (-not $combined.Contains("HTTPS/TLS")) {
  throw "HTTPS/TLS preflight marker is absent."
}

if (-not $combined.Contains("PS C:\path>")) {
  throw "PowerShell prompt warning example is absent."
}

Write-Output "CHECK=OK"
