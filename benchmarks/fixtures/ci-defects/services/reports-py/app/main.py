import os

from fastapi import FastAPI

from app.exports import router as exports_router

app = FastAPI(title="reports")
app.include_router(exports_router)

DATABASE_URL = os.environ["REPORTS_DATABASE_URL"]


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
