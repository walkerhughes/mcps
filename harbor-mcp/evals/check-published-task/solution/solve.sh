#!/bin/bash
# Reference solution (oracle) for the check-published-task eval.
#
# The eval's real subject is the agent-plus-MCP path; this script only needs to
# produce a correctly shaped answer deterministically. When the runner provides
# ground truth via EVAL_EXPECTED_PUBLISHED / EVAL_EXPECTED_CONTENT_HASH (passed
# with `harbor run --ae`), the answer is exact and also satisfies the
# verifier's expected-value check.
set -euo pipefail

mkdir -p /app

if [ "${EVAL_EXPECTED_PUBLISHED:-no}" = "yes" ] && [ -n "${EVAL_EXPECTED_CONTENT_HASH:-}" ]; then
    printf 'yes %s\n' "$EVAL_EXPECTED_CONTENT_HASH" > /app/answer.txt
else
    printf 'no\n' > /app/answer.txt
fi
