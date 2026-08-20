ALTER TABLE deals ADD COLUMN stage TEXT NOT NULL DEFAULT 'lead';

ALTER TABLE deals ADD COLUMN stage_changed_at TEXT;

CREATE INDEX deals_stage_idx ON deals (stage);
