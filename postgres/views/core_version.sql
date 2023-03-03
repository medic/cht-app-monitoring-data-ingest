CREATE OR REPLACE VIEW app_monitoring_core_version AS (
  SELECT
    DISTINCT ON (url_id)
    urls.partner_name,
    created AS last_monitored,
    CASE
      WHEN doc #>>'{version,app}' ~ '^\d*\.\d*\.\d*.*' 
      THEN regexp_split_to_array((doc#>>'{version,app}'), '\.')
      ELSE NULL
    END AS cht_core_version
  FROM monitoring_docs docs
  JOIN monitoring_urls urls ON urls.id = docs.url_id 
  WHERE doctype = 'monitoring'
  ORDER BY url_id, created DESC
);

GRANT SELECT ON app_monitoring_core_version TO superset;
ALTER VIEW public.app_monitoring_core_version OWNER TO full_access;
