CREATE MATERIALIZED VIEW public.app_monitoring_chw_last_sync
TABLESPACE pg_default
AS SELECT fn.partner AS partner_name,
    fn.chw_id,
    fn.chw_username,
    fn.replication_date::date AS last_sync,
    date_part('day'::text, now() - fn.replication_date::date::timestamp with time zone) AS days_since_last_sync
   FROM get_chw_last_sync() fn(partner, chw_id, chw_username, replication_date)
     JOIN impactconfig ic ON fn.partner = ic.partner_name
  WHERE fn.replication_date <> 'unknown'::text
WITH DATA;

GRANT SELECT ON app_monitoring_chw_last_sync TO superset;

-- View indexes:
CREATE UNIQUE INDEX app_monitoring_chw_last_sync_partner_chw ON public.app_monitoring_chw_last_sync USING btree(partner_name, chw_id);
CREATE INDEX app_monitoring_chw_last_sync_chw_last_sync ON public.app_monitoring_chw_last_sync USING btree(chw_id, last_sync);
