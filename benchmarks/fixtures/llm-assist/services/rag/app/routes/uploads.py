from fastapi import APIRouter, Depends, UploadFile
from langchain_core.documents import Document
from langchain_postgres import PGVector
from langchain_text_splitters import RecursiveCharacterTextSplitter

from app.db import DSN
from app.deps import Session, current_session
from app.llm.embeddings import lc_embeddings

router = APIRouter()
community_store = PGVector(collection_name="community_playbooks", embeddings=lc_embeddings, connection=DSN.replace("postgresql://", "postgresql+psycopg://"))
splitter = RecursiveCharacterTextSplitter(chunk_size=1200, chunk_overlap=100)


@router.post("/community/uploads")
async def upload(file: UploadFile, session: Session = Depends(current_session)):
    text = (await file.read()).decode("utf-8", errors="replace")
    docs = [Document(page_content=chunk) for chunk in splitter.split_text(text)]
    community_store.add_documents(docs)
    return {"chunks": len(docs)}
