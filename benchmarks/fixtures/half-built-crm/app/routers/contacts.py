from fastapi import APIRouter, HTTPException

from ..db import execute, query
from ..schemas import ContactIn, ContactOut

router = APIRouter(prefix="/api/contacts", tags=["contacts"])


@router.get("", response_model=list[ContactOut])
def list_contacts(q: str | None = None):
    if q:
        return query(
            "SELECT id, email, display_name, company, phone FROM contacts "
            "WHERE display_name LIKE ? OR email LIKE ? ORDER BY display_name",
            (f"%{q}%", f"%{q}%"),
        )
    return query(
        "SELECT id, email, display_name, company, phone FROM contacts ORDER BY display_name"
    )


@router.get("/{contact_id}", response_model=ContactOut)
def get_contact(contact_id: int):
    rows = query(
        "SELECT id, email, display_name, company, phone FROM contacts WHERE id = ?",
        (contact_id,),
    )
    if not rows:
        raise HTTPException(status_code=404, detail="contact_not_found")
    return rows[0]


@router.post("", response_model=ContactOut, status_code=201)
def create_contact(payload: ContactIn):
    new_id = execute(
        "INSERT INTO contacts (email, display_name, company, phone) VALUES (?, ?, ?, ?)",
        (payload.email, payload.display_name, payload.company, payload.phone),
    )
    return {"id": new_id, **payload.model_dump()}


@router.put("/{contact_id}", response_model=ContactOut)
def update_contact(contact_id: int, payload: ContactIn):
    get_contact(contact_id)
    execute(
        "UPDATE contacts SET email = ?, display_name = ?, company = ?, phone = ? WHERE id = ?",
        (payload.email, payload.display_name, payload.company, payload.phone, contact_id),
    )
    return {"id": contact_id, **payload.model_dump()}


@router.delete("/{contact_id}", status_code=204)
def delete_contact(contact_id: int):
    get_contact(contact_id)
    execute("DELETE FROM contacts WHERE id = ?", (contact_id,))
