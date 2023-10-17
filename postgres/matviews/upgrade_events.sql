CREATE MATERIALIZED VIEW public.app_monitoring_upgrade_events
TABLESPACE pg_default
AS
  SELECT
    fn.partner AS partner_name,
    ic.partner_short_name,
    fn.core_version,
    fn.start_time,
    fn.last_update_time,
    fn.is_success
  FROM get_upgrade_events() AS fn(partner, core_version, start_time, last_update_time, is_success)
  INNER JOIN impactconfig AS ic ON fn.partner = ic.partner_name

WITH DATA;

GRANT SELECT ON app_monitoring_upgrade_events to superset;
ALTER MATERIALIZED VIEW app_monitoring_upgrade_events OWNER TO full_access;

-- View indexes:
CREATE UNIQUE INDEX app_monitoring_upgrade_events_by_start ON public.app_monitoring_upgrade_events USING btree(partner_name, start_time);
