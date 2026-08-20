from datetime import date

from pydantic import BaseModel, EmailStr, Field


class ContactIn(BaseModel):
    email: EmailStr
    display_name: str = Field(min_length=1, max_length=200)
    company: str | None = Field(default=None, max_length=200)
    phone: str | None = Field(default=None, max_length=40)


class ContactOut(ContactIn):
    id: int


class TaskIn(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    due_on: date
    contact_id: int | None = None
    deal_id: int | None = None


class TaskOut(TaskIn):
    id: int
    done: bool
