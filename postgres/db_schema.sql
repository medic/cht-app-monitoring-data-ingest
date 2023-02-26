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
