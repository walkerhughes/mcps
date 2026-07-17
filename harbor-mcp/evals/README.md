# harbor-mcp agentic evals

Three [Harbor](https://github.com/harbor-framework/harbor) tasks that test a
real agent (claude-code) using this repo's MCP server (`harbor-mcp`) inside a
task container. Each task declares the server in `task.toml` via
`[[environment.mcp_servers]]` with `transport = "stdio"`, so the server runs in
the main container and the evals work on both the docker and modal
environments (no docker-only compose sidecar).

Each task's `environment/Dockerfile` installs `harbor-mcp` from GitHub so the
stdio command resolves on PATH. Secrets are never baked into images:
`HARBOR_API_KEY` (and, for write tools, `HARBOR_MCP_ENABLE_WRITES`) are passed
at runtime with `harbor run --ae`.

## The evals

| Eval | What the agent must do | Answer written to `/app/answer.txt` |
| --- | --- | --- |
| `verify-upload` | Confirm the job `$EVAL_JOB_ID` is uploaded to the hub and report its trial count | `yes <trial_count>` or `no` |
| `fetch-job-results` | Report the mean reward of job `$EVAL_JOB_ID` | a plain decimal number, e.g. `0.75` |
| `check-published-task` | Determine whether the package `$EVAL_TASK_REF` (`org/name@ref`) exists on the hub | `yes <64-hex content hash>` or `no` |

## Verification

Each `tests/test.sh` writes `1` or `0` to `/logs/verifier/reward.txt`. Because
the verifier has no hub credentials, it cannot recompute ground truth on its
own; it strictly validates the answer format and, when the host exports
expected-value variables, checks the answer exactly:

| Eval | Optional ground-truth env vars (exported on the host) |
| --- | --- |
| `verify-upload` | `EVAL_EXPECTED_TRIAL_COUNT` |
| `fetch-job-results` | `EVAL_EXPECTED_MEAN_REWARD` |
| `check-published-task` | `EVAL_EXPECTED_PUBLISHED` (`yes`/`no`), `EVAL_EXPECTED_CONTENT_HASH` |

These are resolved into the verifier through `[verifier.env]` templates
(`${VAR:-}`) in each `task.toml`, so exporting them in the shell that runs
`harbor run` is enough. Pass the same values with `--ae` when running the
oracle so `solution/solve.sh` produces the matching exact answer.

## Prerequisites

- `harbor` CLI installed on the host (`uv tool install harbor`).
- `HARBOR_API_KEY`: a Harbor hub API key (`harbor auth login`).
- Claude credentials for the claude-code agent (`ANTHROPIC_API_KEY` or
  `CLAUDE_CODE_OAUTH_TOKEN` in the host environment).
- `EVAL_JOB_ID`: id of a job that is already uploaded to the hub.
- `EVAL_TASK_REF`: a task package reference (`org/name@ref`), e.g.
  `harbor/hello-world@1.0.0`.
- `HARBOR_TEST_ENV`: `docker` (default; needs a local Docker daemon) or
  `modal` (needs Modal credentials).

Note: the CI repo secrets backing these variables are still pending, so CI
does not run the evals yet.

## Running

All three, via the Make target (backed by `scripts/run_evals.sh`):

```bash
export HARBOR_API_KEY=hk_...
export EVAL_JOB_ID=<uploaded job id>
export EVAL_TASK_REF=org/name@ref
make evals
```

Individually:

```bash
harbor run -p evals/verify-upload -a claude-code -e "$HARBOR_TEST_ENV" \
  --ae HARBOR_API_KEY="$HARBOR_API_KEY" \
  --ae EVAL_JOB_ID="$EVAL_JOB_ID"

harbor run -p evals/fetch-job-results -a claude-code -e "$HARBOR_TEST_ENV" \
  --ae HARBOR_API_KEY="$HARBOR_API_KEY" \
  --ae EVAL_JOB_ID="$EVAL_JOB_ID"

harbor run -p evals/check-published-task -a claude-code -e "$HARBOR_TEST_ENV" \
  --ae HARBOR_API_KEY="$HARBOR_API_KEY" \
  --ae EVAL_TASK_REF="$EVAL_TASK_REF"
```

The evals only need read tools, so `HARBOR_MCP_ENABLE_WRITES` is not passed.

## Follow-up: oracle validation

Once the env vars / repo secrets exist, validate each task end to end with the
oracle agent (runs `solution/solve.sh` instead of a model):

```bash
harbor run -p evals/verify-upload -a oracle -e "$HARBOR_TEST_ENV" \
  --ae EVAL_EXPECTED_TRIAL_COUNT="$EVAL_EXPECTED_TRIAL_COUNT"
```

and similarly for the other two tasks with their expected-value variables.
This is tracked as a follow-up; nothing in this directory has been executed
yet.
