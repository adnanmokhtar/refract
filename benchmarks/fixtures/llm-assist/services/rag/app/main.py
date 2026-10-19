from fastapi import FastAPI

from app.cache import enable_semantic_cache
from app.routes import search, uploads

app = FastAPI(title="Quill Desk RAG")
app.include_router(search.router)
app.include_router(uploads.router)

enable_semantic_cache()


@app.get("/healthz")
def healthz() -> dict:
    return {"ok": True}
