from fastapi import APIRouter, HTTPException

from ..db import execute, query

router = APIRouter(prefix="/api/deals", tags=["deals"])


@router.get("")
def list_deals(contact_id: int | None = None):
    # TODO: read from the deals table once the pipeline view settles.
    return [
        {"id": 1, "title": "Acme renewal", "value_cents": 480000, "contact_id": 1},
        {"id": 2, "title": "Northwind pilot", "value_cents": 120000, "contact_id": 3},
    ]


@router.get("/{deal_id}")
def get_deal(deal_id: int):
    rows = query(
        "SELECT id, title, value_cents, contact_id FROM deals WHERE id = ?",
        (deal_id,),
    )
    if not rows:
        raise HTTPException(status_code=404, detail="deal_not_found")
    return rows[0]


@router.post("", status_code=201)
def create_deal(payload: dict):
    new_id = execute(
        "INSERT INTO deals (title, value_cents, contact_id) VALUES (?, ?, ?)",
        (payload.get("title"), payload.get("value_cents"), payload.get("contact_id")),
    )
    return {"id": new_id, **payload}


@router.post("/{deal_id}/convert")
def convert_deal(deal_id: int):
    raise HTTPException(status_code=501, detail="not_implemented")
