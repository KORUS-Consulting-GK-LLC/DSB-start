#requires -Version 5.1
$ErrorActionPreference = "Stop"

$launcherPath = Join-Path $PSScriptRoot "..\install.ps1"
$launcher = [IO.File]::ReadAllText($launcherPath)
$mainMarker = '$runtimeTokenFile = $null'
$mainIndex = $launcher.IndexOf($mainMarker, [StringComparison]::Ordinal)
if ($mainIndex -lt 0) { throw "Launcher main marker was not found." }
$definitions = [ScriptBlock]::Create($launcher.Substring(0, $mainIndex))
. $definitions

$root = Join-Path ([IO.Path]::GetTempPath()) ("dsb-token-safety-" + [Guid]::NewGuid().ToString("N"))
try {
  New-Item -ItemType Directory -Path $root | Out-Null
  & git -C $root init --quiet
  if ($LASTEXITCODE -ne 0) { throw "git init failed." }

  $tracked = Join-Path $root "tracked-token.txt"
  [IO.File]::WriteAllText($tracked, "not-a-real-token", (New-Object Text.UTF8Encoding($false)))
  & git -C $root add -- "tracked-token.txt"
  if ($LASTEXITCODE -ne 0) { throw "git add failed." }
  $blocked = $false
  try {
    Protect-TokenFileFromGit $root $tracked
  } catch {
    $blocked = $_.Exception.Message.StartsWith("SECURITY_BLOCK:")
  }
  if (-not $blocked) { throw "Tracked token was not blocked." }

  $local = Join-Path $root "токен-local.txt"
  [IO.File]::WriteAllText($local, "not-a-real-token", (New-Object Text.UTF8Encoding($false)))
  Protect-TokenFileFromGit $root $local
  & git -C $root check-ignore --quiet -- "токен-local.txt"
  if ($LASTEXITCODE -ne 0) { throw "Local token was not added to .git/info/exclude." }

  Write-Host "TOKEN_SAFETY_TEST=OK"
} finally {
  if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
