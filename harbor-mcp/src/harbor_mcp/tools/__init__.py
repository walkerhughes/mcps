"""Tool registration: each tool module exposes register(mcp); fan out here."""

from typing import Any


def register_all(mcp: Any) -> None:
    # Tool modules (jobs, registry, writes) register here as they land.
    pass
