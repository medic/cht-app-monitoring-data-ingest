CREATE MATERIALIZED VIEW public.app_monitoring_chw_last_sync
TABLESPACE pg_default
AS
  SELECT
    fn.partner AS partner_name,
    fn.chw_id,
    fn.chw_username,
    fn.last_sync,
    EXTRACT(DAY FROM now() - fn.last_sync) AS days_since_last_sync
  FROM get_chw_last_sync() AS fn(partner, chw_id, chw_username, last_sync)
  INNER JOIN impactconfig AS ic ON fn.partner = ic.partner_name
WITH DATA;

GRANT SELECT ON app_monitoring_chw_last_sync TO superset;

-- View indexes:
CREATE UNIQUE INDEX app_monitoring_chw_last_sync_partner_chw ON public.app_monitoring_chw_last_sync USING btree(partner_name, chw_id);
CREATE INDEX app_monitoring_chw_last_sync_chw_last_sync ON public.app_monitoring_chw_last_sync USING btree(chw_id, last_sync);
