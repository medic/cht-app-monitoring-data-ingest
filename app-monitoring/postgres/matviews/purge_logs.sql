DROP MATERIALIZED VIEW if EXISTS app_monitoring_purge_logs;
CREATE MATERIALIZED VIEW app_monitoring_purge_logs AS (
    SELECT
        fn.partner AS partner_name,
        fn.completion_date,
        duration_minutes,
        skipped_contacts,
        error
    FROM
        get_purge_logs() fn
);
ALTER MATERIALIZED VIEW app_monitoring_purge_logs OWNER TO full_access;
GRANT SELECT ON app_monitoring_purge_logs TO superset;
