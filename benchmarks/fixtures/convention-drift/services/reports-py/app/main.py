from fastapi import FastAPI

from app.export import router as export_router
from app.reports import router as reports_router

app = FastAPI(title="reports")
app.include_router(reports_router)
app.include_router(export_router)
