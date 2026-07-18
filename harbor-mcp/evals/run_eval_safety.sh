#!/usr/bin/env bash
# Eval-safety check (backs `make eval-safety`): for every eval, the oracle must
# reach reward 1.0 and the nop agent (which produces no answer) must NOT. This
# proves each eval is solvable and not trivially passable -- run it whenever the
# evals change. No LLM/Anthropic cost (oracle runs solve.sh; nop does nothing).
#
# Each job-based eval gets its own freshly bootstrapped hub job per agent run,
# dropped afterward, so oracle's delete does not disturb nop's run.
#
# Required host environment:
#   HARBOR_API_KEY   Harbor hub API key
# Optional:
#   HARBOR_TEST_ENV  harbor environment provider: docker (default) | modal
#   EVAL_TASK_REF    published task ref for check-published-task
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARBOR_TEST_ENV="${HARBOR_TEST_ENV:-docker}"
EVAL_TASK_REF="${EVAL_TASK_REF:-hello-world/hello-world@1}"
JOBS_DIR="$(mktemp -d)"

# shellcheck source=evals/_hublib.sh
. "$REPO_ROOT/evals/_hublib.sh"

trap 'rm -rf "$JOBS_DIR"' EXIT

die() {
    echo "error: $1" >&2
    exit 1
}

command -v harbor > /dev/null 2>&1 \
    || die "harbor CLI not found on PATH (install with: uv tool install harbor)"
[ -n "${HARBOR_API_KEY:-}" ] \
    || die "HARBOR_API_KEY is not set (mint one with: harbor auth login)"

# Exported so harbor resolves them into each task's [verifier.env] templates.
export HARBOR_API_KEY EVAL_TASK_REF

# perfect_for <agent> <job|none> <eval> [extra --ae...]
# Runs one eval with one agent, managing a fresh bootstrapped job when needed.
# Echoes "yes" if the run reached reward 1.0, else "no".
perfect_for() {
    local agent=$1 needs=$2 name=$3
    shift 3
    local out="$JOBS_DIR/$agent-$name" job="" ae=()
    if [ "$needs" = job ]; then
        job="$(bootstrap_job "$out/boot")" || { echo no; return; }
        ae=(--ae EVAL_JOB_ID="$job")
        export EVAL_JOB_ID="$job"
    fi
    harbor run \
        -p "$REPO_ROOT/evals/$name" \
        -a "$agent" \
        -e "$HARBOR_TEST_ENV" \
        -o "$out" \
        --job-name "$name" \
        --ae HARBOR_API_KEY="$HARBOR_API_KEY" \
        "${ae[@]}" "$@" > /dev/null 2>&1 || true
    if python3 "$REPO_ROOT/evals/check_reward.py" "$out/$name/result.json" "$name" \
        > /dev/null 2>&1; then
        echo yes
    else
        echo no
    fi
    drop_job "$job"
}

assert_eval() {
    local needs=$1 name=$2
    shift 2
    echo "==> $name: oracle must pass, nop must fail"
    [ "$(perfect_for oracle "$needs" "$name" "$@")" = yes ] \
        || die "$name: the ORACLE did not reach reward 1.0 (the eval is broken)"
    [ "$(perfect_for nop "$needs" "$name" "$@")" = no ] \
        || die "$name: the NOP agent reached reward 1.0 (the eval is trivially passable)"
    echo "==> $name: OK (oracle passed, nop failed)"
}

assert_eval job read-job
assert_eval job delete-job --ae HARBOR_MCP_ENABLE_WRITES=true
assert_eval none check-published-task --ae EVAL_TASK_REF="$EVAL_TASK_REF"

echo "==> Eval-safety passed for all evals."
