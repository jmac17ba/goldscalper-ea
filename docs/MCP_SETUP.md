# MCP Servers for Claude Code

This repo ships a project-scoped `.mcp.json` with the 5 commonly recommended
MCP servers for Claude Code. When you open the project in Claude Code, it will
prompt you to approve these project servers before they load.

| Server | Package | Purpose | Needs key? |
| --- | --- | --- | --- |
| `filesystem` | `@modelcontextprotocol/server-filesystem` | Scoped file access to the project dir | No |
| `github` | `@modelcontextprotocol/server-github` | Read/write issues, PRs, repos | Yes |
| `context7` | `@upstash/context7-mcp` | Up-to-date library/API docs | Optional |
| `playwright` | `@playwright/mcp` | Drive a real browser to verify UI | No |
| `sequential-thinking` | `@modelcontextprotocol/server-sequential-thinking` | Step-by-step reasoning scratchpad | No |

All servers run on demand via `npx -y` — nothing is installed globally.

## API keys

Set these in your shell environment (e.g. `~/.zshrc`, `~/.bashrc`) before
launching Claude Code. The config reads them from the environment, so no
secrets are committed to the repo.

```bash
# GitHub: create a fine-grained PAT at https://github.com/settings/tokens
export GITHUB_PERSONAL_ACCESS_TOKEN="ghp_xxx"

# Context7 (optional — raises rate limits): https://context7.com/dashboard
export CONTEXT7_API_KEY="ctx7_xxx"
```

Without `GITHUB_PERSONAL_ACCESS_TOKEN` the github server loads but its calls
will fail auth. `context7` works without a key at a lower rate limit.

## Verifying

```bash
claude mcp list          # shows configured servers + connection status
```

If a server shows as failed, run its command manually to see the error, e.g.:

```bash
npx -y @modelcontextprotocol/server-sequential-thinking
```
