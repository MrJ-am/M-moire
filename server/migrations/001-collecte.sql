CREATE TABLE IF NOT EXISTS corpus (
  version text PRIMARY KEY,
  digest text NOT NULL,
  bank jsonb NOT NULL,
  codebook jsonb NOT NULL,
  imported_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS participations (
  id uuid PRIMARY KEY,
  token_hash text NOT NULL,
  bank_version text NOT NULL REFERENCES corpus(version),
  levels text[] NOT NULL,
  seed bigint NOT NULL CHECK(seed BETWEEN 0 AND 4294967295),
  question_order text[] NOT NULL,
  production_order jsonb NOT NULL,
  started_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  revision integer NOT NULL DEFAULT 0 CHECK(revision >= 0),
  payload_hash text,
  snapshot jsonb NOT NULL DEFAULT '{}'
);
CREATE INDEX IF NOT EXISTS participations_started_idx ON participations(started_at);
CREATE INDEX IF NOT EXISTS participations_version_idx ON participations(bank_version);
CREATE TABLE IF NOT EXISTS answers (
  participation_id uuid NOT NULL REFERENCES participations(id) ON DELETE CASCADE,
  question_id text NOT NULL,
  production_id text NOT NULL,
  note numeric CHECK(note BETWEEN 0 AND 3 AND mod(note * 4, 1) = 0),
  initial_note numeric CHECK(initial_note BETWEEN 0 AND 3 AND mod(initial_note * 4, 1) = 0),
  x double precision NOT NULL CHECK(x BETWEEN -10 AND 10),
  y double precision NOT NULL CHECK(y BETWEEN -10 AND 10),
  z double precision NOT NULL CHECK(z BETWEEN -10 AND 10),
  evaluated_axes text[] NOT NULL,
  PRIMARY KEY(participation_id, production_id)
);
CREATE INDEX IF NOT EXISTS answers_production_idx ON answers(production_id);
CREATE TABLE IF NOT EXISTS interaction_events (
  participation_id uuid NOT NULL REFERENCES participations(id) ON DELETE CASCADE,
  sequence integer NOT NULL,
  event text NOT NULL,
  occurred_at timestamptz NOT NULL,
  elapsed_ms bigint NOT NULL CHECK(elapsed_ms >= 0),
  payload jsonb NOT NULL,
  PRIMARY KEY(participation_id, sequence)
);
CREATE TABLE IF NOT EXISTS administrators (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  username text UNIQUE NOT NULL,
  password_hash text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS administrator_sessions (
  token_hash text PRIMARY KEY,
  administrator_id integer NOT NULL REFERENCES administrators(id) ON DELETE CASCADE,
  expires_at timestamptz NOT NULL
);
