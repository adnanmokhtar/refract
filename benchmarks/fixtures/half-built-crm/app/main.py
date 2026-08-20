from fastapi import FastAPI
from fastapi.templating import Jinja2Templates

from .routers import contacts, deals, tasks

app = FastAPI(title="smallcrm", version="0.3.0")
templates = Jinja2Templates(directory="templates")

app.include_router(contacts.router)
app.include_router(deals.router)
app.include_router(tasks.router)


@app.get("/healthz")
def healthz():
    return {"ok": True}
