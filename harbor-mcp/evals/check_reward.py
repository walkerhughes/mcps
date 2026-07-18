#!/usr/bin/env python3
"""Exit non-zero unless a harbor ``result.json`` shows every trial rewarded 1.0.

Backs the CI reward gate in ``run_evals.sh``: ``harbor run`` returns 0 whatever
the reward, so we inspect the job result ourselves to fail a bad eval.

    python3 check_reward.py <result.json> <eval-name>
    python3 check_reward.py --selftest
"""

import json
import sys
from pathlib import Path


def perfect(stats: dict) -> tuple[bool, str]:
    """True iff the run completed and every trial's reward is 1."""
    if stats.get("n_errored_trials") or not stats.get("n_completed_trials"):
        return False, f"run did not complete cleanly (stats={stats})"
    # evals -> per-eval stats -> metrics is a list of single-key reward dicts
    # (e.g. [{"mean": 1.0}]); our tasks emit one reward, so mean == the reward.
    rewards = [
        value
        for eval_stats in stats.get("evals", {}).values()
        for metric in eval_stats.get("metrics", [])
        for value in metric.values()
    ]
    if not rewards or any(reward != 1 for reward in rewards):
        return False, f"reward not perfect (rewards={rewards})"
    return True, f"reward 1.0 over {stats['n_completed_trials']} trial(s)"


def _selftest() -> None:
    ok = {"n_completed_trials": 1, "evals": {"k": {"metrics": [{"mean": 1.0}]}}}
    assert perfect(ok)[0]
    assert not perfect({**ok, "evals": {"k": {"metrics": [{"mean": 0.0}]}}})[0]
    assert not perfect({**ok, "n_errored_trials": 1})[0]
    assert not perfect({"n_completed_trials": 0, "evals": {}})[0]
    assert not perfect({"n_completed_trials": 1, "evals": {}})[0]  # no rewards
    print("check_reward selftest ok")


def main(argv: list[str]) -> int:
    if argv[1:2] == ["--selftest"]:
        _selftest()
        return 0
    result_path, name = argv[1], argv[2]
    try:
        stats = json.loads(Path(result_path).read_text()).get("stats", {})
    except FileNotFoundError:
        print(f"{name}: no result.json at {result_path}", file=sys.stderr)
        return 1
    ok, msg = perfect(stats)
    print(f"{name}: {msg}", file=sys.stdout if ok else sys.stderr)
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
