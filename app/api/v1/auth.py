"""Backward-compatible auth router import.

Use `app.api.v1.auth_router` for the active implementation.
"""

from app.api.v1.auth_router import router

__all__ = ["router"]
