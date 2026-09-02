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
$u = 'https://raw.githubusercontent.com/KORUS-Consulting-GK-LLC/DSB-start/main/install.ps1'
$p = Join-Path $env:TEMP ('dsb-start-' + [guid]::NewGuid() + '.ps1')
Invoke-WebRequest -UseBasicParsing -Uri $u -OutFile $p
Unblock-File -LiteralPath $p -ErrorAction SilentlyContinue
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $p
```

This does not change the system-wide Windows policy.

## Git is not installed

This is expected on clean corporate machines. The first launcher download does not need Git. After the script starts, it checks Git, Node.js 18+ and Python 3, searches common system/user paths and Codex bundled runtime paths, then tries to install missing tools through `winget`.

If corporate policy blocks `winget`, ask the local administrator to install:

- Git for Windows
- Node.js LTS 18 or newer
- Python 3

Then run the same launcher command again.
