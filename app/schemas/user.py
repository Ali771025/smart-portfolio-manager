"""User profile schemas."""

import uuid
from datetime import datetime

from pydantic import BaseModel, EmailStr, ConfigDict


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    email: EmailStr
    full_name: str
    is_active: bool
    is_verified: bool
    created_at: datetime
