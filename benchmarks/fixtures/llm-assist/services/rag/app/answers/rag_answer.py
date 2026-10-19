"""Agent-side question answering over the workspace's documents."""
from langchain_core.prompts import ChatPromptTemplate

from app.llm.lc_models import answer_llm
from app.retrieval.retriever import DocRetriever

RAG_PROMPT_VERSION = "rag-answer@4"

prompt = ChatPromptTemplate.from_messages(
    [
        ("system", "Answer the agent's question from the context. Cite the document titles you used."),
        ("human", "Context:\n{context}\n\nQuestion: {question}"),
    ]
)
chain = prompt | answer_llm


def answer_question(tenant_id: str, question: str, product: str | None = None):
    docs = DocRetriever(tenant_id).retrieve(question, product=product)
    context = "\n\n".join(d.page_content for d in docs)
    return chain.invoke({"context": context, "question": question})
