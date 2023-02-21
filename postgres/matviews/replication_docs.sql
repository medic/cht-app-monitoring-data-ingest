CREATE MATERIALIZED VIEW public.app_monitoring_replication_docs
TABLESPACE pg_default
AS
  SELECT
    created,
    partner_name,
    COALESCE((doc #>> '{couchdb,medic,doc_count}')::int, 0) AS doc_count
  FROM monitoring_docs AS docs
  INNER JOIN monitoring_urls AS urls ON (docs.url_id=urls.id)
  WHERE doctype = 'monitoring'
WITH DATA;

GRANT SELECT ON app_monitoring_replication_docs to superset;

-- View indexes:
CREATE UNIQUE INDEX app_monitoring_replication_docs_name ON public.app_monitoring_replication_docs USING btree(partner_name, metric, docs_count);
