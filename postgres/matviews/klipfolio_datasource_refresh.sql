DROP MATERIALIZED VIEW IF EXISTS app_monitoring_klipfolio_datasource_refresh;

CREATE MATERIALIZED VIEW app_monitoring_klipfolio_datasource_refresh AS
  WITH refresh_age_CTE AS (
    SELECT
      id,
      url_id,
      created,
      jsonb_array_length(doc) AS total_datasources,
      (jsonb_array_elements(doc)::json ->> 'refresh_interval')::INT AS refresh_interval,
      EXTRACT(epoch FROM AGE(created, (jsonb_array_elements(doc)::json ->> 'date_last_refresh')::TIMESTAMP)) AS refresh_age
    FROM monitoring_docs
    WHERE doctype='klipfolio_datasource'
  )
  SELECT
    docs.id,
    created,
    partner_name,
    total_datasources,
    COUNT(*) FILTER ( WHERE refresh_age <= refresh_interval ) AS successful_refresh,
    COUNT(*) FILTER ( WHERE refresh_age > refresh_interval AND refresh_age <= refresh_interval * 5 ) AS potential_failed_refresh,
    COUNT(*) FILTER ( WHERE refresh_age > refresh_interval * 5 ) AS failed_refresh,
    COUNT(*) FILTER ( WHERE refresh_age > refresh_interval )/total_datasources AS percent_failed_refresh
  FROM refresh_age_CTE AS docs
  LEFT JOIN monitoring_urls AS partners ON (partners.id = docs.url_id)
  WHERE refresh_interval <> 0
  GROUP by docs.id, created, total_datasources, partner_name;

CREATE UNIQUE INDEX IF NOT EXISTS app_monitoring_klipfolio_datasource_refresh_id_created_partner_name ON app_monitoring_klipfolio_datasource_refresh USING btree(id, created, partner_name);

GRANT SELECT ON app_monitoring_klipfolio_datasource_refresh TO superset;