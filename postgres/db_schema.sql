CREATE TABLE public.monitoring_urls (
	id SERIAL PRIMARY KEY,
	url VARCHAR NOT NULL,
  partner_name text,
  klipfolio_client_id text,
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

CREATE TABLE public.monitoring_couchpg (
  partner_name text,
  created DATE NOT NULL,
  seq BIGINT NOT NULL,
  source text NOT NULL,
  
  CONSTRAINT fk_partner_name
    FOREIGN KEY(partner_name)
      REFERENCES impactconfig(partner_name)
);
ALTER TABLE public.monitoring_couchpg OWNER TO full_access;

-- This constraint is used for upsert
-- `ON CONFLICT ON CONSTRAINT monitoring_logs_idx_constraint DO NOTHING`
CREATE UNIQUE INDEX monitoring_logs_idx ON monitoring_logs(url_id, doc_id);
ALTER TABLE monitoring_logs ADD CONSTRAINT monitoring_logs_idx_constraint UNIQUE USING INDEX monitoring_logs_idx;

-- `ON CONFLICT ON CONSTRAINT monitoring_couchpg_idx_constraint DO NOTHING`
CREATE UNIQUE INDEX monitoring_couchpg_idx ON monitoring_couchpg(partner_name, created, source);
ALTER TABLE monitoring_couchpg ADD CONSTRAINT monitoring_couchpg_idx_constraint UNIQUE USING INDEX monitoring_couchpg_idx;
