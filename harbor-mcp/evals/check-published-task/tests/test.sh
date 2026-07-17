#!/bin/bash
# Verifier for the check-published-task eval.
#
# The agent must write exactly one line to /app/answer.txt:
#   "yes <content_hash>"  (package exists; <content_hash> is 64 lowercase hex chars), or
#   "no"                  (package does not exist)
#
# Limitation: without hub access the verifier cannot recompute ground truth,
# so by default it validates the answer format strictly. When the host exports
# EVAL_EXPECTED_PUBLISHED (yes|no) and, for the "yes" case,
# EVAL_EXPECTED_CONTENT_HASH (resolved through [verifier.env] in task.toml),
# the answer must additionally match them exactly.
set -u

ANSWER_FILE=/app/answer.txt
REWARD_DIR=/logs/verifier
REWARD_FILE="$REWARD_DIR/reward.txt"

mkdir -p "$REWARD_DIR"

fail() {
    echo "FAIL: $1" >&2
    echo 0 > "$REWARD_FILE"
    exit 0
}

pass() {
    echo "PASS: $1"
    echo 1 > "$REWARD_FILE"
    exit 0
}

if [ ! -f "$ANSWER_FILE" ]; then
    fail "answer file $ANSWER_FILE does not exist"
fi

# Trim trailing whitespace/newlines; the answer must be a single non-empty line.
answer="$(tr -d '\r' < "$ANSWER_FILE" | sed -e 's/[[:space:]]*$//' -e '/^$/d')"

if [ -z "$answer" ]; then
    fail "answer file $ANSWER_FILE is empty"
fi

if [ "$(printf '%s\n' "$answer" | wc -l | tr -d ' ')" -ne 1 ]; then
    fail "answer file $ANSWER_FILE must contain exactly one non-empty line, got: '$answer'"
fi

if ! printf '%s' "$answer" | grep -Eq '^(yes [0-9a-f]{64}|no)$'; then
    fail "answer '$answer' does not match the required format 'yes <64-hex content hash>' or 'no'"
fi

if [ -n "${EVAL_EXPECTED_PUBLISHED:-}" ]; then
    if [ "$EVAL_EXPECTED_PUBLISHED" = "yes" ]; then
        if [ -z "${EVAL_EXPECTED_CONTENT_HASH:-}" ]; then
            fail "EVAL_EXPECTED_PUBLISHED=yes requires EVAL_EXPECTED_CONTENT_HASH to be set"
        fi
        expected="yes ${EVAL_EXPECTED_CONTENT_HASH}"
    else
        expected="no"
    fi
    if [ "$answer" != "$expected" ]; then
        fail "answer '$answer' does not match expected '$expected' (ref ${EVAL_TASK_REF:-unknown})"
    fi
    pass "answer '$answer' matches expected '$expected'"
fi

pass "answer '$answer' has a valid format (no ground truth provided; format-only check)"
