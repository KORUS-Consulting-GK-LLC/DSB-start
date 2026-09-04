#requires -Version 5.1
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$DsbCoreRoot
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $DsbCoreRoot).Path
$plan = Get-Content -LiteralPath (Join-Path $root "infra\connect\install-plan.json.tmpl") -Raw | ConvertFrom-Json
$launcher = Get-Content -LiteralPath (Join-Path $PSScriptRoot "..\install.ps1") -Raw

$versionMatch = [regex]::Match($launcher, '\$LauncherVersion\s*=\s*"([^"]+)"')
$contractMatch = [regex]::Match($launcher, '\$SupportedContractVersion\s*=\s*"([^"]+)"')
if (-not $versionMatch.Success -or -not $contractMatch.Success) {
  throw "Launcher version constants were not found."
}
if ([string]$plan.contract_version -ne $contractMatch.Groups[1].Value) {
  throw "Launcher and DSB-Core contract versions differ."
}
if ([Version]$versionMatch.Groups[1].Value -lt [Version]([string]$plan.minimum_launcher_version)) {
  throw "Launcher is older than DSB-Core minimum_launcher_version."
}

Write-Host "CONTRACT_CHECK=OK"
