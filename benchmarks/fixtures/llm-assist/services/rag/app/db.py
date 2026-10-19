import os
from contextlib import contextmanager

import psycopg
from pgvector.psycopg import register_vector

DSN = os.environ.get("DATABASE_URL", "postgresql://rag_app@localhost:5432/quilldesk")


@contextmanager
def get_conn():
    with psycopg.connect(DSN) as conn:
        register_vector(conn)
        yield conn
