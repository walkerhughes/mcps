# Shared helpers for the eval runners. Sourced, not executed.
#
# Requires in the environment: HARBOR_API_KEY, HARBOR_TEST_ENV (docker|modal),
# and REPO_ROOT (repo root path). `harbor` must be on PATH.

# The task the bootstrap runs to mint a hub job: Harbor's own maintained
# hello-world (the member task of the public harbor/hello-world dataset), run
# straight from the registry so we neither vendor a copy nor reach into tests/.
# Pinned to an immutable revision. check-published-task points at the same task.
BOOTSTRAP_TASK="${BOOTSTRAP_TASK:-hello-world/hello-world@1}"

# bootstrap_job <out_dir>
# Runs BOOTSTRAP_TASK with the oracle agent (no LLM cost) and uploads it,
# creating a fresh hub job. Job artifacts land under <out_dir>. Echoes the new
# hub job id on stdout; all harbor chatter goes to stderr.
bootstrap_job() {
    local out=$1
    harbor run \
        -y \
        -t "$BOOTSTRAP_TASK" \
        -a oracle \
        -e "$HARBOR_TEST_ENV" \
        -o "$out" \
        --job-name harbor-mcp-evals \
        --upload \
        -q >&2
    python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["id"])' \
        "$out/harbor-mcp-evals/result.json"
}

# drop_job <job_id>
# Best-effort delete of a hub job (idempotent; no-op on empty id).
drop_job() {
    [ -n "${1:-}" ] || return 0
    harbor hub job delete "$1" -y > /dev/null 2>&1 || true
}
