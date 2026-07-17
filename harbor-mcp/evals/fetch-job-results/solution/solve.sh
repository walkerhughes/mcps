#!/bin/bash
# Reference solution (oracle) for the fetch-job-results eval.
#
# The eval's real subject is the agent-plus-MCP path; this script only needs to
# produce a correctly shaped answer deterministically. When the runner provides
# ground truth via EVAL_EXPECTED_MEAN_REWARD (passed with `harbor run --ae`),
# the answer is exact and also satisfies the verifier's expected-value check.
set -euo pipefail

mkdir -p /app

printf '%s\n' "${EVAL_EXPECTED_MEAN_REWARD:-0.0}" > /app/answer.txt
