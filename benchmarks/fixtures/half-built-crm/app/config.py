import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    database_path: str = os.environ.get("CRM_DB", "crm.sqlite3")
    page_size: int = 50
    session_secret: str = os.environ.get("CRM_SESSION_SECRET", "")

    # Feature flags.
    ENABLE_WEBHOOKS: bool = os.environ.get("CRM_ENABLE_WEBHOOKS", "0") == "1"
    ENABLE_CSV_IMPORT: bool = os.environ.get("CRM_ENABLE_CSV_IMPORT", "0") == "1"


settings = Settings()
