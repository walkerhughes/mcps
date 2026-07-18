# harbor-mcp agentic evals

Agentic [Harbor](https://github.com/harbor-framework/harbor) tasks that gate on
whether the **harbor-mcp capability surface works against the hub** for a real
agent (claude-code). Each task declares this repo's MCP server (`harbor-mcp`) in
`task.toml` via `[[environment.mcp_servers]]` with `transport = "stdio"`, so the
server runs in the main container and the evals work on both the docker and
modal environments (no docker-only compose sidecar).

Each task's `environment/Dockerfile` installs `harbor-mcp` from GitHub so the
stdio command resolves on PATH. Secrets are never baked into images:
`HARBOR_API_KEY` (and, for write tools, `HARBOR_MCP_ENABLE_WRITES`) are passed
at runtime with `harbor run --ae`.

## The evals

The set is deliberately minimal -- one eval per capability bucket, covering
reads and writes against the hub:

| Eval | Bucket | The agent must (via the MCP) | Answer in `/app/answer.txt` |
| --- | --- | --- | --- |
| `read-job` | job reads | report the mean reward of job `$EVAL_JOB_ID` | a plain decimal, e.g. `1.0` |
| `delete-job` | job writes | delete job `$EVAL_JOB_ID` (writes enabled; confirm-gated) | `deleted` |
| `check-published-task` | registry reads | decide whether `$EVAL_TASK_REF` is published | `yes` or `no` |

Auth (`whoami`) is exercised implicitly -- nothing reads or writes without it.
Deliberately **out of scope** for a per-PR gate: `publish_task` /
`publish_dataset` (published versions are immutable/content-addressed, not
cleanly reversible) and `set_job_visibility` / `share_job` (niche).

## Self-truthing verifiers

Verifiers do not rely on planted expected values. `HARBOR_API_KEY` is threaded
into each verifier through `[verifier.env]` (`${HARBOR_API_KEY:-}`, resolved
from the host at `harbor run` time), so every `tests/test.sh` recomputes the
ground truth live from the hub with the `harbor` CLI and compares:

| Eval | How the verifier self-truths |
| --- | --- |
| `read-job` | `harbor hub job show $EVAL_JOB_ID --json` -> `.stats.avg_reward`, matched within 1e-6 |
| `delete-job` | `harbor hub job show $EVAL_JOB_ID --json` must be empty (job gone) |
| `check-published-task` | `harbor download $EVAL_TASK_REF` succeeds iff published |

Oracles (`solution/solve.sh`) answer the same questions independently, also via
the `harbor` CLI.

## Running

```bash
export HARBOR_API_KEY=hk_...
make evals          # the merge gate: drives the evals with claude-code
```

`make evals` (backed by `evals/run_evals.sh`) is self-contained:

1. **Bootstraps a hub job** for the job-based evals -- runs the
   `tests/e2e/fixtures/hello-task` fixture with the deterministic oracle agent,
   uploads it, and uses that fresh job id as `EVAL_JOB_ID`. A fresh id per run
   means no cross-run collisions.
2. **Runs the three evals** with claude-code and gates each on reward `1.0`
   (`evals/check_reward.py`) -- `harbor run` exits 0 regardless of reward, so
   the runner inspects the result itself. `read-job` reads the job; `delete-job`
   deletes it (doubling as cleanup) and is the only eval passed
   `--ae HARBOR_MCP_ENABLE_WRITES=true`; `check-published-task` checks the pinned
   public task `hello-world/hello-world@1`.
3. **Cleans up** the bootstrapped job on exit if anything left it behind.

`HARBOR_TEST_ENV` selects `docker` (default; needs a local Docker daemon) or
`modal` (needs Modal credentials); CI's gate uses modal.

## Eval-safety check

```bash
make eval-safety    # oracle must pass, nop must fail -- no LLM cost
```

`evals/run_eval_safety.sh` runs every eval twice: with the `oracle` agent (must
reach reward 1.0 -- the eval is solvable) and with the `nop` agent, which
produces no answer (must fail -- the eval is not trivially passable). It
bootstraps a fresh job per job-based agent run and drops it afterward. This runs
in CI via [`eval-safety.yml`](../.github/workflows/eval-safety.yml) on every PR
that touches `evals/**`, so the evals stay honest independently of the merge
gate.

## Two-phase rollout

1. This PR adds the evals and the eval-safety check (not yet a merge gate).
2. A follow-up adds the `evals` job to [`ci.yml`](../.github/workflows/ci.yml):
   it runs `make evals` with claude-code on modal for every PR to `main` and is
   marked a required status check, gating merges on the MCP capabilities.

Note: the eval images install `harbor-mcp` from the GitHub default branch, so
today the gate exercises the published server, not an open PR's server changes.
Building the image from the PR checkout is a tracked follow-up.

## Other examples

`hello-mcp/` is a standalone demo (not part of the gate) of a multi-container
task that declares its own MCP server; see its README.
