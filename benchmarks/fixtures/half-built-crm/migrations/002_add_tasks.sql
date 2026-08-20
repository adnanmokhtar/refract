CREATE TABLE tasks (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  title       TEXT NOT NULL,
  due_on      TEXT NOT NULL,
  contact_id  INTEGER REFERENCES contacts (id),
  deal_id     INTEGER REFERENCES deals (id),
  done        INTEGER NOT NULL DEFAULT 0,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX tasks_due_idx ON tasks (due_on);
