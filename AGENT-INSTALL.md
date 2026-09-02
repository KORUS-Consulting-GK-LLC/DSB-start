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

3. Before asking the user for the token, verify that the installer is actually waiting for input:
   - good state: the terminal shows `[DSB-start] READY_FOR_TOKEN` and then a plain `Token:` prompt;
   - bad state: the terminal shows the normal PowerShell prompt like `PS C:\path>`; in this state the installer is not waiting, so do not ask for the token.
4. When the terminal is in the good state, tell the user to type only the token value into that terminal prompt and press Enter. The user must not type the literal prefix `Token:`.
5. If the installer asks which configuration to connect, ask the user which configuration pair they need, or use the default pair if the user already named it.
6. Report only the result and any non-secret blocker.

## Important details

- The first download does not require Git. It uses HTTPS through PowerShell.
- Git, Node.js 18+ and Python 3 are checked by `install.ps1`. If they are missing, the installer tries to find bundled runtime tools or install them through `winget`.
- If Windows blocks direct script execution, rerun the exact command above. It starts a separate PowerShell process with process-local `ExecutionPolicy Bypass`.
- Do not run the downloaded temp `install.ps1` directly as `.\install.ps1` or `& $p`.
- Do not edit the downloaded temp `install.ps1` for the current machine. Fixes belong in this repository, not in the temporary copy.
- Do not pass the token in argv, URL, environment variables, Git files, or chat.
- If the user typed `Token: ...` at a normal `PS ...>` prompt, treat the token as exposed, stop using it, and restart with a fresh token.
