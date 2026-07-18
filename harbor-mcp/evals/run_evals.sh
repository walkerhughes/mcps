#!/usr/bin/env bash
# Gate runner (backs `make evals`): drives the harbor-mcp hub-capability evals
# with the claude-code agent and fails if any does not reach reward 1.0. It
# proves the MCP's basic hub operations work for a real agent:
#
#   read-job              read a job's mean reward   (job reads)
#   delete-job            delete a job (writes gate) (job writes)
#   check-published-task  is a task published?       (registry reads)
#
# Self-contained: bootstraps its own hub job with the oracle (no LLM cost) for
# the job-based evals, and deletes it on exit. Verifiers are self-truthing --
# they recompute ground truth from the hub via the harbor CLI, so no
# EVAL_EXPECTED_* constants are needed (HARBOR_API_KEY is threaded to them via
# each task's [verifier.env]).
#
# Required host environment:
#   HARBOR_API_KEY   Harbor hub API key (mint with `harbor auth login`)
#   ANTHROPIC_API_KEY (or CLAUDE_CODE_OAUTH_TOKEN) for the claude-code agent
# Optional:
#   HARBOR_TEST_ENV  harbor environment provider: docker (default) | modal
#   EVAL_TASK_REF    published task ref for check-published-task
#                    (default: hello-world/hello-world@1, an immutable public task)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARBOR_TEST_ENV="${HARBOR_TEST_ENV:-docker}"
EVAL_TASK_REF="${EVAL_TASK_REF:-hello-world/hello-world@1}"
JOBS_DIR="$(mktemp -d)"

# shellcheck source=evals/_hublib.sh
. "$REPO_ROOT/evals/_hublib.sh"

JOB_ID=""
cleanup() {
    rm -rf "$JOBS_DIR"
    drop_job "$JOB_ID"
}
trap cleanup EXIT

die() {
    echo "error: $1" >&2
    exit 1
}

command -v harbor > /dev/null 2>&1 \
    || die "harbor CLI not found on PATH (install with: uv tool install harbor)"
[ -n "${HARBOR_API_KEY:-}" ] \
    || die "HARBOR_API_KEY is not set (mint one with: harbor auth login)"
if [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
    echo "warning: neither ANTHROPIC_API_KEY nor CLAUDE_CODE_OAUTH_TOKEN is set;" \
        "the claude-code agent will likely fail to authenticate" >&2
fi

# Exported so harbor resolves them into each task's [verifier.env] templates.
export HARBOR_API_KEY EVAL_TASK_REF

echo "==> Bootstrapping a hub job (oracle, env: $HARBOR_TEST_ENV)"
JOB_ID="$(bootstrap_job "$JOBS_DIR")"
export EVAL_JOB_ID="$JOB_ID"
echo "==> Bootstrapped job $JOB_ID"

run_eval() {
    local name=$1
    shift
    echo "==> Running eval: $name (claude-code, env: $HARBOR_TEST_ENV)"
    # -y auto-confirms harbor's prompt for [verifier.env] host vars (it would
    # abort in non-interactive CI otherwise).
    harbor run \
        -y \
        -p "$REPO_ROOT/evals/$name" \
        -a claude-code \
        -e "$HARBOR_TEST_ENV" \
        -o "$JOBS_DIR" \
        --job-name "$name" \
        --ae HARBOR_API_KEY="$HARBOR_API_KEY" \
        "$@"
    # harbor run exits 0 regardless of reward; gate on a perfect result so CI
    # (and `make evals`) fails the moment an eval regresses.
    if ! python3 "$REPO_ROOT/evals/check_reward.py" "$JOBS_DIR/$name/result.json" "$name"; then
        echo "--- $name verifier output ---" >&2
        cat "$JOBS_DIR/$name"/*/verifier/test-stdout.txt >&2 2>/dev/null || true
        die "$name did not reach reward 1.0"
    fi
}

run_eval read-job --ae EVAL_JOB_ID="$JOB_ID"
# delete-job removes the bootstrapped job (doubling as cleanup); it needs writes.
run_eval delete-job --ae EVAL_JOB_ID="$JOB_ID" --ae HARBOR_MCP_ENABLE_WRITES=true
JOB_ID=""  # already deleted; don't re-delete in the trap
run_eval check-published-task --ae EVAL_TASK_REF="$EVAL_TASK_REF"

echo "==> All evals passed with reward 1.0."
