# Agent install procedure

This file is the canonical public procedure for agents that connect a local project to DepSandbox.

## Goal

Configure the current project for DepSandbox MCP using the protected `/connect/` bootstrap. The user must type the MCP token into the local terminal prompt. The token must not be requested or pasted in chat.

## Exact procedure

1. Open the terminal in the root of the user's current project.
2. Run this command:

```powershell
$u = 'https://raw.githubusercontent.com/KORUS-Consulting-GK-LLC/DSB-start/main/install.ps1'
$p = Join-Path $env:TEMP ('dsb-start-' + [guid]::NewGuid() + '.ps1')
Invoke-WebRequest -UseBasicParsing -Uri $u -OutFile $p
Unblock-File -LiteralPath $p -ErrorAction SilentlyContinue
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $p
```

3. When the terminal asks `Token:`, tell the user to type the token into that terminal prompt and press Enter.
4. If the installer asks which configuration to connect, ask the user which configuration pair they need, or use the default pair if the user already named it.
5. Report only the result and any non-secret blocker.

## Important details

- The first download does not require Git. It uses HTTPS through PowerShell.
- Git, Node.js 18+ and Python 3 are checked by `install.ps1`. If they are missing, the installer tries to find bundled runtime tools or install them through `winget`.
- If Windows blocks direct script execution, rerun the exact command above. It starts a separate PowerShell process with process-local `ExecutionPolicy Bypass`.
- Do not run the downloaded temp `install.ps1` directly as `.\install.ps1` or `& $p`.
- Do not edit the downloaded temp `install.ps1` for the current machine. Fixes belong in this repository, not in the temporary copy.
- Do not pass the token in argv, URL, environment variables, Git files, or chat.
