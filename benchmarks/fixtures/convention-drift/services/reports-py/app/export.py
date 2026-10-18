import csv
import io

import requests
from fastapi import APIRouter
from fastapi.responses import StreamingResponse

router = APIRouter(prefix="/exports")


@router.get("/orders.csv")
def export_orders(since: str) -> StreamingResponse:
    rows = requests.get("http://api:3000/api/v2/orders", params={"since": since}, timeout=10).json()["items"]
    buffer = io.StringIO()
    writer = csv.writer(buffer)
    writer.writerow(["id", "reference", "total_minor"])
    for row in rows:
        writer.writerow([row["id"], row["reference"], row["totalMinor"]])
    buffer.seek(0)
    return StreamingResponse(buffer, media_type="text/csv")
