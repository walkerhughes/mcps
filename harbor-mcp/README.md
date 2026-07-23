# harbor-mcp

An [MCP](https://modelcontextprotocol.io) server for the [Harbor](https://www.harborframework.com) hub. It exposes your evaluation jobs, trials, uploads, and published packages as tools an agent (Claude Code, etc.) can call directly, so you can ask "did my upload work?" or "what was the mean reward on job X?" without leaving the chat.

It wraps Harbor's own async client classes (`HubClient`, `UploadDB`, `RegistryDB`, `Uploader`, `Downloader`, `Publisher`), so there is no separate API layer to maintain. Harbor reads `HARBOR_API_KEY` and handles token exchange itself.

This lives in the [`mcps`](../) monorepo, consolidated from a standalone repo with full commit history preserved (`git log`/`git blame` resolve inside this directory).

## Setup

```bash
uv sync
cp .env.example .env      # then set HARBOR_API_KEY
```

Mint a key with `harbor auth login` (it stores one in `~/.harbor/credentials.json`) and put it in `.env`:

```
HARBOR_API_KEY=sk-harbor-...
```

The repo ships a [`.mcp.json`](.mcp.json) that Claude Code auto-discovers when started from this directory. It sources `.env` before launching, so your key never lives in the config. Verify the connection by asking the agent to call `whoami`.

## Tools

Read tools work with any valid `HARBOR_API_KEY`. Write tools are gated (see below).

| Tool | What it does |
|------|--------------|
| `whoami` | Confirm credentials; returns the user id and key source (never the key) |
| `list_jobs` | List your hub jobs with trial counts, cost, and reward |
| `get_job_overview` | Roll up one job: counts, retries, tokens, cost, reward, models |
| `get_job_trials` | List a job's trials (task, status, reward, error, duration) |
| `get_trial_detail` | One trial's full record |
| `check_job_upload` | Verify an upload: row exists, archive present, per-status counts, missing archives |
| `check_task_published` | Whether a task version exists in the registry (missing → `published: false`) |
| `resolve_dataset` | Resolve a dataset version and list its member tasks |
| `upload_job` | Upload a local job directory (idempotent, resumable) |
| `publish_task` / `publish_dataset` | Publish a local task/dataset to the registry |
| `download_job` | Download and extract a job's archive locally |
| `set_job_visibility` | Flip a job public/private |
| `share_job` | Grant read access to orgs/users |
| `delete_job` | Delete a job's rows (permanent; requires `confirm`) |

## Write gating

Every write tool refuses unless `HARBOR_MCP_ENABLE_WRITES=true` in the server environment. `delete_job` additionally requires `confirm=true` per call, which the agent should pass only after you explicitly approve deleting a specific job. This keeps read-only use the safe default.

## Testing

| Tier | Command | Needs | Uses an LLM? |
|------|---------|-------|--------------|
| unit | `make test` | nothing (harbor clients mocked) | no |
| integration | `make test-integration` | `HARBOR_API_KEY` | no (tools driven directly over MCP stdio) |
| e2e | `make test-e2e` | `HARBOR_API_KEY` + `HARBOR_TEST_ENV` | no (oracle agent runs `solve.sh`) |
| evals | `make evals` | `HARBOR_API_KEY` + `ANTHROPIC_API_KEY` + `EVAL_*` | yes (agent rollouts) |

`HARBOR_TEST_ENV` selects where harbor runs the fixture job: `docker` (default) or `modal`. Modal needs its own credentials (`modal token new`) and the `modal` extra (`uv sync --dev --extra modal`), which pulls in harbor's modal support; the base install omits it. The integration and e2e tiers are deterministic (no agent decisions), so they gate PRs without spending on model calls; the `evals/` agent rollouts run separately once tool use is proven at the lower tiers.

The `harbor` dependency is pinned exactly because this server imports Harbor internals, which are not a stable public API. Bump it deliberately.
