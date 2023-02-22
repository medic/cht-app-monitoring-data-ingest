CREATE MATERIALIZED VIEW public.app_monitoring_replication_performance
AS
  SELECT
    fn.partner AS partner_name,
    ic.partner_short_name,
    fn.metric,
    fn.period_start,
    fn.min,
    fn.sum,
    fn.mean,
    fn.max,
    fn.first_quartile,
    fn.third_quartile
  FROM get_replication_doc_count() AS fn(partner, period_start, metric, min, sum, mean, max, first_quartile, third_quartile)
  INNER JOIN impactconfig AS ic ON fn.partner = ic.partner_name

WITH DATA;

GRANT SELECT ON app_monitoring_replication_performance to superset;

-- View indexes:
CREATE UNIQUE INDEX app_monitoring_replication_performance_index ON public.app_monitoring_replication_performance USING btree(partner_name, metric, period_start);
