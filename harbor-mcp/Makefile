.PHONY: test test-integration test-e2e evals lint

test:
	uv run pytest tests/unit

test-integration:
	uv run pytest tests/integration -m integration

test-e2e:
	uv run pytest tests/e2e -m e2e

evals:
	./scripts/run_evals.sh

lint:
	uv run ruff check . && uv run ruff format --check .
