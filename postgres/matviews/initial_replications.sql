CREATE MATERIALIZED VIEW public.app_monitoring_initial_replications
TABLESPACE pg_default
AS 
  SELECT
    fn.partner AS partner_name,
    fn.date,
    fn.count_initial_replications
  FROM get_initial_replications() fn(partner, date, count_initial_replications)

WITH DATA;

GRANT SELECT ON  app_monitoring_initial_replications to superset;

-- View indexes:
CREATE UNIQUE INDEX app_monitoring_initial_replications_partner_name ON public.app_monitoring_initial_replications USING btree (partner_name, date);
