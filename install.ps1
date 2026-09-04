#requires -Version 5.1
[CmdletBinding()]
param(
  [string]$ProjectRoot = (Get-Location).Path,
  [ValidateSet("auto", "codex", "cursor")]
  [string]$Client = "auto",
  [string[]]$Configuration = @(),
  [switch]$AllConfigurations,
  [switch]$BaseOnly,
  [switch]$DryRun,
  [switch]$NoInstallPrerequisites,
  [switch]$KeepWorkDir,
  [switch]$KeepRunArtifacts,
  [switch]$RemoveTokenFileAfterRead,
  [string]$TokenFile,
  [string]$ConnectRoot = "https://mcp.dep1c.com/connect"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

function Write-Step {
  param([string]$Message)
  Write-Host ("[DSB-start] " + $Message)
}

function Resolve-RequiredPath {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    throw ("Path not found: " + $Path)
  }
  return (Resolve-Path -LiteralPath $Path).Path
}

function Update-ProcessPath {
  $pathParts = @()
  if ($env:Path) { $pathParts += $env:Path.Split(";") }
  $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  if ($machinePath) { $pathParts += $machinePath.Split(";") }
  if ($userPath) { $pathParts += $userPath.Split(";") }
  $pathParts += @(
    (Join-Path $env:ProgramFiles "Git\cmd"),
    (Join-Path $env:ProgramFiles "nodejs"),
    (Join-Path $env:LOCALAPPDATA "Programs\Python\Launcher"),
    (Join-Path $env:LOCALAPPDATA "Programs\Python\Python313"),
    (Join-Path $env:LOCALAPPDATA "Programs\Python\Python312"),
    (Join-Path $env:LOCALAPPDATA "Programs\Python\Python311")
  )
  if ($env:USERPROFILE) {
    $codexDeps = Join-Path $env:USERPROFILE ".cache\codex-runtimes\codex-primary-runtime\dependencies"
    $pathParts += @(
      (Join-Path $codexDeps "native\git\cmd"),
      (Join-Path $codexDeps "native\git\bin"),
      (Join-Path $codexDeps "node"),
      (Join-Path $codexDeps "python"),
      (Join-Path $codexDeps "python\Scripts")
    )
  }
  $env:Path = (($pathParts | ForEach-Object { ([string]$_).Trim().Trim('"') } | Where-Object { $_ } | Select-Object -Unique) -join ";")
}

function Get-CommandSource {
  param([string]$Name)
  $command = Get-Command $Name -ErrorAction SilentlyContinue
  if ($null -eq $command) { return $null }
  return $command.Source
}

function Test-NativeCommand {
  param(
    [string]$Name,
    [string[]]$Arguments = @("--version")
  )
  $source = Get-CommandSource $Name
  if (-not $source) { return $false }
  $oldPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = "Continue"
    & $source @Arguments *> $null
    return ($LASTEXITCODE -eq 0)
  } finally {
    $ErrorActionPreference = $oldPreference
  }
}

function Test-Node18 {
  $source = Get-CommandSource "node"
  if (-not $source) { return $false }
  $versionText = (& $source --version 2>$null)
  if ($LASTEXITCODE -ne 0) { return $false }
  $versionText = ([string]$versionText).Trim().TrimStart("v")
  try {
    $version = [Version]$versionText
    return ($version.Major -ge 18)
  } catch {
    return $false
  }
}

function Get-ConnectTarget {
  param([string]$ConnectRootValue)
  try {
    $uri = [Uri]$ConnectRootValue
  } catch {
    throw ("Invalid ConnectRoot URI: " + $ConnectRootValue)
  }
  if (-not $uri.Host) { throw ("ConnectRoot URI has no host: " + $ConnectRootValue) }
  $port = $uri.Port
  if ($uri.IsDefaultPort) {
    if ($uri.Scheme -eq "https") { $port = 443 }
    elseif ($uri.Scheme -eq "http") { $port = 80 }
  }
  return [PSCustomObject]@{
    Host = $uri.DnsSafeHost
    Port = [int]$port
  }
}

function Get-DomainUnavailableUserMessage {
  return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("0L7QsdGA0LDRgtC40YLQtdGB0Ywg0Log0LDQtNC80LjQvdC40YHRgtGA0LDRgtC+0YDRgywg0L/QtdGB0L7Rh9C90LjRhtCwINC90LXQtNC+0YHRgtGD0L/QvdCwINC/0L4g0LTQvtC80LXQvdC90L7QvNGDINC40LzQtdC90Lg="))
}

function Throw-ConnectAccessError {
  param(
    [string]$Reason,
    [string]$HostName,
    [int]$Port
  )
  throw ("DEPSANDBOX_DOMAIN_UNAVAILABLE: " + $HostName + ":" + $Port + " is unavailable by DNS name. " + $Reason + ". " + (Get-DomainUnavailableUserMessage))
}

function Test-ConnectEndpointAccess {
  param([string]$ConnectRootValue)
  $target = Get-ConnectTarget $ConnectRootValue
  Write-Step ("Checking access to " + $target.Host + ":" + $target.Port + " by DNS name")

  $addresses = @()
  $dnsError = $null
  try {
    $dnsTask = [Net.Dns]::GetHostAddressesAsync($target.Host)
    $dnsCompleted = $false
    try {
      $dnsCompleted = $dnsTask.Wait(5000)
    } catch {
      $dnsError = "DNS resolution failed: " + $_.Exception.GetBaseException().Message
    }
    if (-not $dnsError) {
      if (-not $dnsCompleted) {
        $dnsError = "DNS resolution timed out"
      } else {
        $addresses = @($dnsTask.Result)
      }
    }
  } catch {
    $dnsError = "DNS resolution failed: " + $_.Exception.Message
  }
  if ($dnsError) { Throw-ConnectAccessError $dnsError $target.Host $target.Port }
  if ($addresses.Count -eq 0) {
    Throw-ConnectAccessError "DNS returned no addresses" $target.Host $target.Port
  }

  $client = [Net.Sockets.TcpClient]::new()
  $async = $null
  $tcpError = $null
  try {
    $async = $client.BeginConnect($target.Host, $target.Port, $null, $null)
    if (-not $async.AsyncWaitHandle.WaitOne(5000, $false)) {
      $tcpError = "TCP connection timed out"
    } else {
      $client.EndConnect($async)
    }
  } catch {
    $tcpError = "TCP connection failed: " + $_.Exception.Message
  } finally {
    if ($async -and $async.AsyncWaitHandle) { $async.AsyncWaitHandle.Close() }
    $client.Close()
  }
  if ($tcpError) { Throw-ConnectAccessError $tcpError $target.Host $target.Port }

  $uri = [Uri]$ConnectRootValue
  if ($uri.Scheme -eq "https") {
    $tlsError = $null
    $response = $null
    try {
      $request = [Net.WebRequest]::Create($uri.AbsoluteUri)
      $request.Method = "HEAD"
      $request.Timeout = 5000
      $request.AllowAutoRedirect = $false
      $request.UserAgent = "DSB-start preflight"
      $response = $request.GetResponse()
    } catch [Net.WebException] {
      if ($_.Exception.Response) {
        $response = $_.Exception.Response
      } else {
        $tlsError = "HTTPS/TLS request failed: " + $_.Exception.Message
      }
    } catch {
      $tlsError = "HTTPS/TLS request failed: " + $_.Exception.Message
    } finally {
      if ($response) { $response.Close() }
    }
    if ($tlsError) { Throw-ConnectAccessError $tlsError $target.Host $target.Port }
  }
}

function Get-PythonCommand {
  if (Test-NativeCommand "py" @("-3", "--version")) { return "py" }
  if (Test-NativeCommand "py" @("--version")) { return "py" }
  if (Test-NativeCommand "python" @("--version")) { return "python" }
  return $null
}

function Install-WithWinget {
  param(
    [string]$DisplayName,
    [string]$PackageId
  )
  if ($NoInstallPrerequisites) {
    throw ($DisplayName + " is missing. Install it or rerun without -NoInstallPrerequisites.")
  }
  $winget = Get-CommandSource "winget"
  if (-not $winget) {
    throw ($DisplayName + " is missing and winget is not available.")
  }
  Write-Step ("Installing " + $DisplayName + " with winget")
  $args = @(
    "install",
    "--id", $PackageId,
    "--exact",
    "--silent",
    "--accept-package-agreements",
    "--accept-source-agreements"
  )
  & $winget @args
  if ($LASTEXITCODE -ne 0) {
    throw ("winget failed while installing " + $DisplayName + " with exit code " + $LASTEXITCODE)
  }
  Update-ProcessPath
}

function Ensure-Prerequisites {
  Update-ProcessPath
  if (-not (Test-NativeCommand "git" @("--version"))) {
    Install-WithWinget "Git" "Git.Git"
  }
  if (-not (Test-Node18)) {
    Install-WithWinget "Node.js LTS" "OpenJS.NodeJS.LTS"
  }
  if (-not (Get-PythonCommand)) {
    Install-WithWinget "Python 3" "Python.Python.3.13"
  }
  if (-not (Test-NativeCommand "git" @("--version"))) { throw "Git is still unavailable after installation." }
  if (-not (Test-Node18)) { throw "Node.js 18+ is still unavailable after installation." }
  if (-not (Get-PythonCommand)) { throw "Python 3 is still unavailable after installation." }
}

function Get-PlainToken {
  if ($TokenFile) {
    $tokenPath = Resolve-RequiredPath $TokenFile
    $script:sourceTokenFile = $tokenPath
    $value = [IO.File]::ReadAllText($tokenPath, [Text.Encoding]::UTF8).Trim()
    if (-not $value) { throw "Token file is empty." }
    if ($value -match "\s") { throw "Token file must contain one token without whitespace." }
    return $value
  }
  Write-Step "Enter DepSandbox token. Input is hidden and is not sent through chat."
  Write-Step "READY_FOR_TOKEN: the next prompt must be a plain hidden 'Token:' prompt, not a PowerShell 'PS ...>' command prompt."
  $secure = Read-Host "Token" -AsSecureString
  if ($secure.Length -eq 0) { throw "Token is empty." }
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try {
    $value = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
  if (-not $value) { throw "Token is empty." }
  if ($value -match "\s") { throw "Token must not contain whitespace." }
  return $value
}

function Set-OwnerOnlyAcl {
  param(
    [string]$Path,
    [switch]$Directory
  )
  try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $acl = Get-Acl -LiteralPath $Path
    $acl.SetAccessRuleProtection($true, $false)
    if ($Directory) {
      $rule = New-Object Security.AccessControl.FileSystemAccessRule(
        $identity,
        "FullControl",
        "ContainerInherit,ObjectInherit",
        "None",
        "Allow"
      )
    } else {
      $rule = New-Object Security.AccessControl.FileSystemAccessRule($identity, "FullControl", "Allow")
    }
    $acl.AddAccessRule($rule)
    Set-Acl -LiteralPath $Path -AclObject $acl
  } catch {
    Write-Step "Warning: failed to restrict temporary file ACL. Continuing with current user temp directory."
  }
}

function Invoke-ProtectedJson {
  param(
    [string]$Uri,
    [string]$Token
  )
  $headers = @{
    Authorization = ("Bearer " + $Token)
    Accept = "application/json"
  }
  try {
    return Invoke-RestMethod -Method Get -Uri $Uri -Headers $headers -MaximumRedirection 0 -ErrorAction Stop
  } catch {
    throw ("Protected request failed: " + $Uri + ". Check token, DNS/VPN and TLS trust.")
  }
}

function Save-ProtectedFile {
  param(
    [string]$Uri,
    [string]$Token,
    [string]$OutFile
  )
  $headers = @{
    Authorization = ("Bearer " + $Token)
    Accept = "application/octet-stream"
  }
  try {
    Invoke-WebRequest -UseBasicParsing -Method Get -Uri $Uri -Headers $headers -OutFile $OutFile -MaximumRedirection 0 -ErrorAction Stop
  } catch {
    throw ("Protected download failed: " + $Uri + ". Check token, DNS/VPN and TLS trust.")
  }
}

function Invoke-NativeCapture {
  param(
    [string]$FilePath,
    [string[]]$Arguments
  )
  $output = @(& $FilePath @Arguments 2>&1 | ForEach-Object { [string]$_ })
  $code = $LASTEXITCODE
  if ($null -eq $code) { $code = 0 }
  return [PSCustomObject]@{
    Code = [int]$code
    Output = $output
  }
}

function Get-LastJsonObject {
  param([string[]]$Lines)
  for ($index = $Lines.Count - 1; $index -ge 0; $index--) {
    $line = ([string]$Lines[$index]).Trim()
    if (-not $line.StartsWith("{")) { continue }
    try {
      return ($line | ConvertFrom-Json)
    } catch {
      continue
    }
  }
  return $null
}

function Get-ActiveConfigurationIds {
  param(
    [string]$ConnectRootValue,
    [string]$Token
  )
  $catalog = Invoke-ProtectedJson (($ConnectRootValue.TrimEnd("/")) + "/v1/catalog.json") $Token
  return @($catalog.configurations | Where-Object { $_.lifecycle -eq "active" } | ForEach-Object { $_.id })
}

function Select-ConfigurationsFromPayload {
  param($Payload)
  $configs = @($Payload.configurations)
  if ($configs.Count -eq 0) { throw "Bootstrap requested a selection but returned an empty catalog." }

  Write-Host ""
  Write-Step "Select configuration MCP pair"
  Write-Host "  0) Base MCP only"
  for ($index = 0; $index -lt $configs.Count; $index++) {
    $item = $configs[$index]
    $number = $index + 1
    $label = [string]$item.display_name
    $id = [string]$item.id
    $life = [string]$item.lifecycle
    Write-Host ("  " + $number + ") " + $id + " - " + $label + " [" + $life + "]")
  }
  Write-Host "  all) All active configurations"
  $answer = Read-Host "Enter number, comma-separated numbers, all, or 0"
  $answer = ([string]$answer).Trim()
  if ($answer -eq "0") { return @() }
  if ($answer.ToLowerInvariant() -eq "all") {
    return @($configs | Where-Object { $_.lifecycle -eq "active" } | ForEach-Object { $_.id })
  }
  $ids = @()
  foreach ($part in $answer.Split(",")) {
    $trimmed = $part.Trim()
    if (-not $trimmed) { continue }
    $parsed = 0
    if (-not [int]::TryParse($trimmed, [ref]$parsed)) {
      throw ("Invalid selection item: " + $trimmed)
    }
    if ($parsed -lt 1 -or $parsed -gt $configs.Count) {
      throw ("Selection item is out of range: " + $trimmed)
    }
    $ids += [string]$configs[$parsed - 1].id
  }
  if ($ids.Count -eq 0) { throw "No configuration selected." }
  return $ids
}

function Invoke-Bootstrap {
  param(
    [string]$NodePath,
    [string]$BootstrapPath,
    [string]$ProjectRootValue,
    [string]$ClientValue,
    [string]$RuntimeTokenFile,
    [string[]]$SelectedConfiguration,
    [switch]$BaseOnlyValue,
    [switch]$DryRunValue
  )
  $args = @($BootstrapPath, "--project-root", $ProjectRootValue, "--token-file", $RuntimeTokenFile)
  if ($ClientValue -ne "auto") { $args += @("--client", $ClientValue) }
  if ($BaseOnlyValue) {
    $args += "--base-only"
  } elseif ($SelectedConfiguration.Count -gt 0) {
    $args += @("--configuration", ($SelectedConfiguration -join ","))
  }
  if ($DryRunValue) { $args += "--dry-run" }
  if ($KeepRunArtifacts) { $args += "--keep-run-artifacts" }
  return Invoke-NativeCapture $NodePath $args
}

function Normalize-ConfigurationInput {
  param([string[]]$Values)
  $result = @()
  foreach ($value in $Values) {
    foreach ($part in ([string]$value).Split(",")) {
      $trimmed = $part.Trim()
      if ($trimmed) { $result += $trimmed }
    }
  }
  return $result
}

$runtimeTokenFile = $null
$sourceTokenFile = $null
$temporaryTokenFile = $false
$workDir = $null
$projectRootPath = $null
$exitCode = 0

try {
  $projectRootPath = Resolve-RequiredPath $ProjectRoot
  if ($AllConfigurations -and $BaseOnly) { throw "Use either -AllConfigurations or -BaseOnly, not both." }
  if ($AllConfigurations -and $Configuration.Count -gt 0) { throw "Use either -AllConfigurations or -Configuration, not both." }

  Write-Step ("Project root: " + $projectRootPath)
  Ensure-Prerequisites

  Test-ConnectEndpointAccess $ConnectRoot

  $token = Get-PlainToken
  $connectRootValue = $ConnectRoot.TrimEnd("/")
  $runName = "dsb-start-" + ([Guid]::NewGuid().ToString("N"))
  $workDir = Join-Path ([IO.Path]::GetTempPath()) $runName
  New-Item -ItemType Directory -Force -Path $workDir | Out-Null
  Set-OwnerOnlyAcl $workDir -Directory

  $runtimeTokenFile = Join-Path $workDir "token.txt"
  $utf8NoBom = New-Object Text.UTF8Encoding($false)
  [IO.File]::WriteAllText($runtimeTokenFile, $token, $utf8NoBom)
  Set-OwnerOnlyAcl $runtimeTokenFile
  $temporaryTokenFile = $true

  Write-Step "Fetching protected install plan"
  $plan = Invoke-ProtectedJson ($connectRootValue + "/v1/install-plan.json") $token
  $bootstrapUrl = [string]$plan.entrypoint.url
  $expectedHash = ([string]$plan.entrypoint.sha256).ToLowerInvariant()
  if (-not $bootstrapUrl) { throw "Install plan does not contain entrypoint.url." }
  if (-not $expectedHash) { throw "Install plan does not contain entrypoint.sha256." }

  $bootstrapPath = Join-Path $workDir "bootstrap.mjs"
  Write-Step "Downloading protected bootstrap"
  Save-ProtectedFile $bootstrapUrl $token $bootstrapPath
  $actualHash = ((Get-FileHash -Algorithm SHA256 -LiteralPath $bootstrapPath).Hash).ToLowerInvariant()
  if ($actualHash -ne $expectedHash) {
    throw "Bootstrap SHA-256 mismatch."
  }

  $selected = @(Normalize-ConfigurationInput $Configuration)
  if ($AllConfigurations) {
    $selected = Get-ActiveConfigurationIds $connectRootValue $token
  }

  $nodePath = Get-CommandSource "node"
  $first = Invoke-Bootstrap $nodePath $bootstrapPath $projectRootPath $Client $runtimeTokenFile $selected $BaseOnly $DryRun
  $first.Output | ForEach-Object { Write-Host $_ }

  if ($first.Code -eq 20) {
    $payload = Get-LastJsonObject $first.Output
    if ($null -eq $payload) { throw "Bootstrap requested selection but no JSON payload was found." }
    $selected = Select-ConfigurationsFromPayload $payload
    $baseOnlyAfterSelection = ($selected.Count -eq 0)
    $second = Invoke-Bootstrap $nodePath $bootstrapPath $projectRootPath $Client $runtimeTokenFile $selected $baseOnlyAfterSelection $DryRun
    $second.Output | ForEach-Object { Write-Host $_ }
    if ($second.Code -ne 0) {
      throw ("Bootstrap failed with exit code " + $second.Code)
    }
  } elseif ($first.Code -ne 0) {
    throw ("Bootstrap failed with exit code " + $first.Code)
  }

  Write-Step "Done. Restart the IDE or open a new agent task if MCP tools are not visible yet."
} catch {
  Write-Step ("ERROR: " + $_.Exception.Message)
  $exitCode = 1
} finally {
  if ($temporaryTokenFile -and $runtimeTokenFile -and (Test-Path -LiteralPath $runtimeTokenFile)) {
    Remove-Item -LiteralPath $runtimeTokenFile -Force
  }
  if ($workDir -and (Test-Path -LiteralPath $workDir) -and -not $KeepWorkDir) {
    Remove-Item -LiteralPath $workDir -Recurse -Force
  }
  if ($RemoveTokenFileAfterRead -and $sourceTokenFile -and $projectRootPath -and (Test-Path -LiteralPath $sourceTokenFile)) {
    try {
      $projectFull = ([IO.Path]::GetFullPath($projectRootPath)).TrimEnd("\") + "\"
      $tokenFull = [IO.Path]::GetFullPath($sourceTokenFile)
      if ($tokenFull.StartsWith($projectFull, [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $sourceTokenFile -Force
        Write-Step "Removed one-time token file from the project directory."
      } else {
        Write-Step "Token file was outside the project directory, leaving it untouched."
      }
    } catch {
      Write-Step "Warning: failed to remove token file. Delete it manually if it was one-time."
    }
  }
}

if ($exitCode -ne 0) {
  exit $exitCode
}
