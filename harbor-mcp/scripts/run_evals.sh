#!/usr/bin/env bash
# Runs the three harbor-mcp agentic evals with claude-code (backs `make evals`).
#
# Required host environment:
#   HARBOR_API_KEY   Harbor hub API key (mint with `harbor auth login`)
#   EVAL_JOB_ID      id of a job already uploaded to the hub
#                    (verify-upload, fetch-job-results)
#   EVAL_TASK_REF    task package reference org/name@ref
#                    (check-published-task)
# Optional:
#   HARBOR_TEST_ENV  harbor environment provider: docker (default) | modal
#   EVAL_EXPECTED_*  ground-truth values for exact verification
#                    (see evals/README.md)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARBOR_TEST_ENV="${HARBOR_TEST_ENV:-docker}"

die() {
    echo "error: $1" >&2
    exit 1
}

command -v harbor > /dev/null 2>&1 \
    || die "harbor CLI not found on PATH (install with: uv tool install harbor)"
[ -n "${HARBOR_API_KEY:-}" ] \
    || die "HARBOR_API_KEY is not set (mint one with: harbor auth login)"
[ -n "${EVAL_JOB_ID:-}" ] \
    || die "EVAL_JOB_ID is not set (id of a job already uploaded to the hub)"
[ -n "${EVAL_TASK_REF:-}" ] \
    || die "EVAL_TASK_REF is not set (task package reference, e.g. org/name@1.0.0)"

if [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
    echo "warning: neither ANTHROPIC_API_KEY nor CLAUDE_CODE_OAUTH_TOKEN is set;" \
        "the claude-code agent will likely fail to authenticate" >&2
fi

run_eval() {
    local name=$1
    shift
    echo "==> Running eval: $name (env: $HARBOR_TEST_ENV)"
    harbor run \
        -p "$REPO_ROOT/evals/$name" \
        -a claude-code \
        -e "$HARBOR_TEST_ENV" \
        --ae HARBOR_API_KEY="$HARBOR_API_KEY" \
        "$@"
}

run_eval verify-upload --ae EVAL_JOB_ID="$EVAL_JOB_ID"
run_eval fetch-job-results --ae EVAL_JOB_ID="$EVAL_JOB_ID"
run_eval check-published-task --ae EVAL_TASK_REF="$EVAL_TASK_REF"

echo "==> All three evals submitted. Check the harbor job output above for rewards."
