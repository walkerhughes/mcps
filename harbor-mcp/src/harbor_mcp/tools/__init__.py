"""Tool registration: each tool module exposes register(mcp); fan out here."""

from typing import Any

from harbor_mcp.tools import jobs, registry


def register_all(mcp: Any) -> None:
    jobs.register(mcp)
    registry.register(mcp)
