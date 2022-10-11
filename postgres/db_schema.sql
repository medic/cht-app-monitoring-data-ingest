CREATE TABLE public.monitoring_urls (
	id SERIAL PRIMARY KEY,
	url VARCHAR NOT NULL,
  partner_name text,
	enabled BOOLEAN NOT NULL DEFAULT true,
  access_level smallint NOT NULL DEFAULT 1,
  CONSTRAINT fk_partner_name
    FOREIGN KEY(partner_name)
      REFERENCES impactconfig(partner_name)
);
ALTER TABLE public.monitoring_urls OWNER TO full_access;

CREATE TABLE public.monitoring_docs (
  id SERIAL PRIMARY KEY,
  url_id INTEGER NOT NULL,
  doctype VARCHAR NOT NULL,
  created TIMESTAMP DEFAULT NOW(),
  doc JSONB NOT NULL,
  CONSTRAINT fk_url
    FOREIGN KEY(url_id)
      REFERENCES monitoring_urls(id)
);
ALTER TABLE public.monitoring_docs OWNER TO full_access;

CREATE TABLE public.monitoring_logs (
  id SERIAL PRIMARY KEY,
  url_id INTEGER NOT NULL,
  created TIMESTAMP DEFAULT NOW(),
  doc_id VARCHAR NOT NULL,
  doc JSONB NOT NULL,
  CONSTRAINT fk_url
    FOREIGN KEY(url_id)
      REFERENCES monitoring_urls(id)
);
ALTER TABLE public.monitoring_logs OWNER TO full_access;

-- This constraint is used for upsert
-- `ON CONFLICT ON CONSTRAINT monitoring_logs_idx_constraint DO NOTHING`
CREATE UNIQUE INDEX monitoring_logs_idx ON monitoring_logs(url_id, doc_id);
ALTER TABLE monitoring_logs ADD CONSTRAINT monitoring_logs_idx_constraint UNIQUE USING INDEX monitoring_logs_idx;
