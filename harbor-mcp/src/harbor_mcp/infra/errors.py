"""Error handling for MCP tools: the model gets recovery guidance, never a traceback."""

import functools
import json
import logging
from collections.abc import Awaitable, Callable
from typing import Any

from harbor.auth.errors import AuthenticationError
from postgrest.exceptions import APIError
from storage3.exceptions import StorageApiError

logger = logging.getLogger(__name__)

AUTH_SUGGESTIONS = [
    "Set HARBOR_API_KEY in this repo's .env file (see .env.example).",
    "Mint a key by running `harbor auth login` in a terminal.",
    "Call the whoami tool to verify credentials once set.",
]


def error_response(
    message: str, suggestions: list[str] | None = None, **extra: Any
) -> str:
    payload: dict[str, Any] = {"error": message}
    if suggestions:
        payload["suggestions"] = suggestions
    payload.update(extra)
    return json.dumps(payload, default=str)


def guarded_tool(func: Callable[..., Awaitable[str]]) -> Callable[..., Awaitable[str]]:
    """Wrap an async tool so every failure becomes an actionable JSON payload."""

    @functools.wraps(func)
    async def wrapper(*args: Any, **kwargs: Any) -> str:
        try:
            return await func(*args, **kwargs)
        except AuthenticationError as exc:
            return error_response(str(exc), suggestions=AUTH_SUGGESTIONS)
        except APIError as exc:
            logger.debug("postgrest error in %s", func.__name__, exc_info=True)
            return error_response(
                f"Harbor hub query failed: {exc.message}",
                suggestions=[
                    "Check the id/org/name arguments exist and are spelled correctly.",
                    "Rows hidden by permissions look identical to missing rows; "
                    "confirm the resource belongs to your account.",
                ],
                code=exc.code,
            )
        except StorageApiError as exc:
            logger.debug("storage error in %s", func.__name__, exc_info=True)
            return error_response(
                f"Harbor hub storage operation failed: {exc.message}",
                suggestions=[
                    "Retry once; if it persists, verify the archive exists via check_job_upload."
                ],
                status=exc.status,
            )
        except (ValueError, FileNotFoundError, RuntimeError, PermissionError) as exc:
            return error_response(str(exc))
        except Exception as exc:  # noqa: BLE001 - last resort: never leak a traceback
            logger.exception("unexpected error in %s", func.__name__)
            return error_response(f"{type(exc).__name__}: {exc}")

    return wrapper
