CREATE MATERIALIZED VIEW public.app_monitoring_replication_docs
TABLESPACE pg_default
AS
  SELECT
    fn.partner AS partner_name,
    ic.partner_short_name,
    fn.metric,
    fn.docs_count
  FROM get_replication_doc_count() AS fn(partner, metric, docs_count)
  INNER JOIN impactconfig AS ic ON fn.partner = ic.partner_name

WITH DATA;

GRANT SELECT ON app_monitoring_replication_docs to superset;

-- View indexes:
CREATE UNIQUE INDEX app_monitoring_replication_docs_name ON public.app_monitoring_replication_docs USING btree(partner_name, metric, docs_count);
