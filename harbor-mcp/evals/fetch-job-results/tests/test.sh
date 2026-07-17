#!/bin/bash
# Verifier for the fetch-job-results eval.
#
# The agent must write exactly one line to /app/answer.txt containing the
# job's mean reward as a plain decimal number (for example "0.75").
#
# Limitation: without hub access the verifier cannot recompute ground truth,
# so by default it validates the answer format strictly. When the host exports
# EVAL_EXPECTED_MEAN_REWARD (resolved through [verifier.env] in task.toml), the
# answer must additionally match it numerically within 1e-6.
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

if ! printf '%s' "$answer" | grep -Eq '^-?[0-9]+(\.[0-9]+)?$'; then
    fail "answer '$answer' is not a plain decimal number"
fi

if [ -n "${EVAL_EXPECTED_MEAN_REWARD:-}" ]; then
    if ! awk -v got="$answer" -v want="$EVAL_EXPECTED_MEAN_REWARD" \
        'BEGIN { diff = got - want; if (diff < 0) diff = -diff; exit !(diff <= 1e-6) }'; then
        fail "answer '$answer' does not match expected mean reward '$EVAL_EXPECTED_MEAN_REWARD' (job ${EVAL_JOB_ID:-unknown})"
    fi
    pass "answer '$answer' matches expected mean reward '$EVAL_EXPECTED_MEAN_REWARD'"
fi

pass "answer '$answer' has a valid format (no ground truth provided; format-only check)"
