CREATE MATERIALIZED VIEW public.app_monitoring_chw_engagement
TABLESPACE pg_default
AS
  SELECT * FROM app_monitoring_chw_last_sync WHERE last_sync BETWEEN now() - '60 days'::interval AND now() - '30 days'::interval
  EXCEPT
  SELECT * FROM app_monitoring_chw_last_sync WHERE last_sync > now() - '30 days'::interval;
WITH DATA;

GRANT SELECT ON app_monitoring_chw_engagement TO superset;
-- View indexes:
CREATE UNIQUE INDEX app_monitoring_chw_engagement_partner_chw ON public.app_monitoring_chw_engagement USING btree(partner_name, chw_id);
