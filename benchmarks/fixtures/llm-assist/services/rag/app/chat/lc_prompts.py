"""Messages for the ticket side-panel chat (LangChain)."""
from langchain_core.documents import Document
from langchain_core.messages import BaseMessage, HumanMessage, SystemMessage

TICKET_CHAT_VERSION = "ticket-chat@2"


def ticket_chat_messages(ticket, chunks: list[Document], question: str) -> list[BaseMessage]:
    context = "\n".join("<doc>" + c.page_content + "</doc>" for c in chunks)
    return [
        SystemMessage(content=f"You help an agent resolve ticket #{ticket.number}: {ticket.subject}. Answer from the documents."),
        HumanMessage(content=f"{question}\n\nDocuments:\n{context}"),
    ]
