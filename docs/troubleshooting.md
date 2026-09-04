# Troubleshooting

## PowerShell says script execution is disabled

Symptom:

```text
PSSecurityException
UnauthorizedAccess
running scripts is disabled on this system
```

Run the public launcher through a new PowerShell process with process-local execution policy:

```powershell
$tokenFile = Resolve-Path -LiteralPath '.depsandbox-token.txt'
$clientId = 'zcode'
$u = 'https://raw.githubusercontent.com/KORUS-Consulting-GK-LLC/DSB-start/b1e2c8ca3aaf080c5bd0b8284f189e3dd769f873/install.ps1'
$expected = '6afcefe6049bb34f45398bea042b05c7c514a7f42ef7aa6596e8b3f1c7f8584d'
$launcherDir = Join-Path (Get-Location) '.depsandbox\launcher'
New-Item -ItemType Directory -Force -Path $launcherDir | Out-Null
$p = Join-Path $launcherDir 'install.ps1'
Invoke-WebRequest -UseBasicParsing -Uri $u -OutFile $p -TimeoutSec 20
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash.ToLowerInvariant() -ne $expected) { throw 'DSB-start launcher integrity check failed.' }
Unblock-File -LiteralPath $p -ErrorAction SilentlyContinue
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $p -Client $clientId -TokenFile $tokenFile -RemoveTokenFileAfterRead
```

This does not change the system-wide Windows policy.

## Git is not installed

This is expected on clean corporate machines. The first launcher download does not need Git. After the script starts, it checks Git, Node.js 18+ and Python 3, searches common system/user paths and Codex bundled runtime paths, then tries to install missing tools through `winget`.

If corporate policy blocks `winget`, ask the local administrator to install:

- Git for Windows
- Node.js LTS 18 or newer
- Python 3

Then run the same launcher command again.

## Token was typed as a PowerShell command in an old flow

Symptom:

```text
PS C:\project> Token: ...
Token: The term 'Token:' is not recognized...
```

The installer was not waiting for token input. The user typed the token into a normal PowerShell command prompt. The current supported flow is token-file based, so this should happen only when someone follows an outdated instruction.

What to do:

1. Treat that token as exposed and replace it.
2. Put the fresh token into a local file in the project root, for example `.depsandbox-token.txt`.
3. Run the launcher command again with `-TokenFile`.
4. Do not paste the token into chat, argv, URL, Git, or a normal PowerShell prompt like `PS C:\path>`.

## Antivirus reports PDM:Trojan.Win32.Generic for a generated wrapper

This is usually a behavior-based detection, not proof that the public launcher contains malware. The risky pattern is an extra temporary PowerShell wrapper that starts a transcript, runs another downloaded `.ps1`, and passes paths through `%TEMP%`.

Use the command from `AGENT-INSTALL.md` directly from the project terminal. Do not create `dsb-run*.ps1`, do not use `Start-Transcript`, and keep the token file in the project root until the launcher reads it.

The official command downloads a fixed Git commit and verifies SHA-256. A
different path or hash is not an equivalent launcher.

## Base-only setup unexpectedly asks for a configuration

Symptom:

```text
install.ps1 -BaseOnly
```

still reaches the interactive configuration-selection step.

This was caused by positional PowerShell parameter binding when an empty configuration array was passed to `Invoke-Bootstrap`. Current launcher builds the bootstrap call with named parameters, so `-BaseOnly` is preserved even when no configuration IDs are selected.
