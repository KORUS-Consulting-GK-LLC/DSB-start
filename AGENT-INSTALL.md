# Agent install procedure

This file is the canonical public procedure for agents that connect a local project to DepSandbox.

## Goal

Configure the current project for DepSandbox MCP using the protected `/connect/` bootstrap. The user creates a local token file in the project root, the agent finds it, passes its path to the launcher, and the launcher reads it without printing the value.

## Exact procedure

1. Open the terminal in the root of the user's current project.
2. The launcher checks DNS, TCP, and HTTPS/TLS access to `mcp.dep1c.com:443` before reading the token. If it prints `DEPSANDBOX_DOMAIN_UNAVAILABLE`, stop the installation and tell the user exactly: `обратитесь к администратору, песочница недоступна по доменному имени`. Do not edit `hosts` as part of the official flow.
3. Resolve the token file path. If the user only says that the token file is in the project root, inspect only top-level file names and choose the single obvious candidate (`token`, `токен`, `depsandbox`, or a small `.txt` file). If there are several candidates, ask for the file name. If there is no token file, ask the user to create one in the project root and rerun the connection request. Do not read the token into chat output.
4. Run this command after setting `$tokenFile` to the resolved local file. Run it directly in the project terminal: do not create an extra wrapper `.ps1`, do not start `Start-Transcript`, and do not copy the token file to `%TEMP%`.

```powershell
$tokenFile = Resolve-Path -LiteralPath '.depsandbox-token.txt'
$u = 'https://raw.githubusercontent.com/KORUS-Consulting-GK-LLC/DSB-start/main/install.ps1'
$launcherDir = Join-Path (Get-Location) '.depsandbox\launcher'
New-Item -ItemType Directory -Force -Path $launcherDir | Out-Null
$p = Join-Path $launcherDir 'install.ps1'
Invoke-WebRequest -UseBasicParsing -Uri $u -OutFile $p
Unblock-File -LiteralPath $p -ErrorAction SilentlyContinue
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $p -TokenFile $tokenFile -RemoveTokenFileAfterRead
```

5. If the installer asks which configuration to connect, ask the user which configuration pair they need, or use the default pair if the user already named it.
6. Report only the result and any non-secret blocker.

## Important details

- The first download does not require Git. It uses HTTPS through PowerShell.
- Git, Node.js 18+ and Python 3 are checked by `install.ps1`. If they are missing, the installer tries to find bundled runtime tools or install them through `winget`.
- If Windows blocks direct script execution, rerun the exact command above. It starts a separate PowerShell process with process-local `ExecutionPolicy Bypass`.
- Do not run the downloaded temp `install.ps1` directly as `.\install.ps1` or `& $p`.
- Do not edit the downloaded `install.ps1` for the current machine. Fixes belong in this repository, not in the downloaded copy.
- `-RemoveTokenFileAfterRead` removes the source token file only when it is inside the project directory. Files outside the project are left untouched.
- Use `-KeepRunArtifacts` only for debugging a failed installation. The normal successful installation should leave only compact state and final project guidance.
- `DEPSANDBOX_DOMAIN_UNAVAILABLE` means the current machine cannot reach the sandbox by `mcp.dep1c.com:443` or cannot complete standard HTTPS/TLS; this is a local DNS/VPN/proxy/certificate issue to escalate to the administrator.
- Keep the user's real agent environment. Do not ask whether it is Codex or Cursor when the current client is something else. If the protected bootstrap cannot write a native MCP config for the current client, use the generated DepSandbox MCP map and apply it through that client's normal MCP/settings mechanism.
- Do not pass the token in argv, URL, Git files, logs, or chat. The launcher may store it only in the approved local client secret mechanism, such as the Codex user environment variable referenced by project config.
