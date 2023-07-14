CREATE MATERIALIZED VIEW public.app_monitoring_replication_by_status
TABLESPACE pg_default
AS
  SELECT
    fn.partner AS partner_name,
    ic.partner_short_name,
    fn.period_start,
    fn.replication_success_count,
    fn.replication_failure_count,
    fn.replication_denied_count
  FROM get_replication_by_status() AS fn(partner, period_start, replication_success_count, replication_failure_count, replication_denied_count)
  INNER JOIN impactconfig AS ic ON fn.partner = ic.partner_name

WITH DATA;

GRANT SELECT ON app_monitoring_replication_by_status to superset;

-- View indexes:
CREATE UNIQUE INDEX app_monitoring_replication_by_status_name ON public.app_monitoring_replication_by_status USING btree(partner_name, period_start, replication_success_count, replication_failure_count, replication_denied_count);
