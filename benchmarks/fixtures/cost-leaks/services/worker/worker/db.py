from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from worker import settings

engine = create_engine(settings.DATABASE_URL, pool_size=5, max_overflow=0, pool_pre_ping=True)
Session = sessionmaker(engine, expire_on_commit=False)
