# DSB-start Agent Rules

- Keep this repository secret-free. Do not commit Bearer tokens, generated MCP configs, logs with Authorization headers, or user-specific paths.
- `install.ps1` must remain compatible with Windows PowerShell 5.1 and PowerShell 7. Keep executable script text ASCII-only unless there is a deliberate tested reason.
- The user-facing UX goal is one natural-language request to the local agent. The agent runs the launcher from the target project root. The token is requested locally by the launcher, not pasted into an agent chat.
- The launcher may download protected DepSandbox bootstrap resources only from `https://mcp.dep1c.com/connect/`.
- Never pass the Bearer token in argv, URL query, Git, README examples, or report payloads.
- Prefer deterministic checks over informal instructions: parse PowerShell syntax, verify SHA-256 from install plan, and preserve project files by delegating real setup to the protected bootstrap.
