-- Migration additive : compatible avec le retour à la version applicative antérieure.
ALTER TABLE administrator_sessions ADD COLUMN IF NOT EXISTS last_seen timestamptz NOT NULL DEFAULT now();
CREATE INDEX IF NOT EXISTS administrator_sessions_activity_idx ON administrator_sessions(administrator_id,last_seen);
