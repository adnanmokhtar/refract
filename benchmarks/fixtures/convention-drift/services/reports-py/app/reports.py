from fastapi import APIRouter

from app.http_client import get_json

router = APIRouter(prefix="/reports")


def summarise(items: list[dict]) -> dict:
    total = sum(item["totalMinor"] for item in items)
    return {"count": len(items), "total_minor": total}


@router.get("/daily")
def GetReport(day: str) -> dict:
    items = get_json("orders", day=day)["items"]
    return summarise(items)
