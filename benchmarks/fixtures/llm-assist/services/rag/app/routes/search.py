from fastapi import APIRouter, Depends
from langchain_postgres import PGVector
from pydantic import BaseModel

from app.db import DSN
from app.deps import Session, current_session
from app.llm.embeddings import lc_embeddings

router = APIRouter()
doc_store = PGVector(collection_name="workspace_docs", embeddings=lc_embeddings, connection=DSN.replace("postgresql://", "postgresql+psycopg://"))


class SearchBody(BaseModel):
    tenant_id: str
    query: str


@router.post("/search")
def search(body: SearchBody, session: Session = Depends(current_session)):
    results = doc_store.similarity_search(body.query, k=5, filter={"tenant_id": body.tenant_id})
    return [{"title": d.metadata.get("title"), "snippet": d.page_content[:240]} for d in results]
