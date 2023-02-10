CREATE MATERIALIZED VIEW public.app_monitoring_form_completions
TABLESPACE pg_default
AS 
  SELECT
    fn.partner AS partner_name,
    ic.partner_short_name,
    fn.form_name,
    fn.load_count,
    fn.complete_count
  FROM get_forms_by_completion() fn(partner, form_name, load_count, complete_count)
  JOIN impactconfig ic ON fn.partner = ic.partner_name

WITH DATA;

GRANT SELECT ON  app_monitoring_form_completions to superset;

-- View indexes:
CREATE UNIQUE INDEX app_monitoring_form_completions_partner_name ON public.app_monitoring_form_completions USING btree (partner_name, form_name, load_count, complete_count);
