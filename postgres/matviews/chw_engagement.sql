CREATE MATERIALIZED VIEW public.app_monitoring_chw_engagement
TABLESPACE pg_default
AS
  SELECT
    fn.partner AS partner_name,
    fn.chw_id,
    fn.chw_username,
    fn.last_sync
  FROM get_chw_last_sync() AS fn(partner, chw_id, chw_username, last_sync)
  INNER JOIN impactconfig AS ic ON fn.partner = ic.partner_name
WITH DATA;

GRANT SELECT ON app_monitoring_chw_engagement TO superset;

-- View indexes:
CREATE UNIQUE INDEX app_monitoring_chw_engagement_partner_chw ON public.app_monitoring_chw_engagement USING btree(partner_name, chw_id);
