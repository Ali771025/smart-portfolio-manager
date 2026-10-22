"""User profile management endpoints."""

from fastapi import APIRouter

from app.core.deps import CurrentUser
from app.schemas.user import UserRead

router = APIRouter()


@router.get("/me", response_model=UserRead)
async def get_current_user_profile(current_user: CurrentUser) -> UserRead:
    """Return the authenticated user's profile."""
    return UserRead.model_validate(current_user)
