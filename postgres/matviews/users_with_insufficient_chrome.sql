DROP MATERIALIZED VIEW if EXISTS app_monitoring_users_with_insufficient_chrome;
CREATE MATERIALIZED VIEW app_monitoring_users_with_insufficient_chrome AS (
    SELECT
        partner AS partner_name,
        user_name,
        chrome_version
    FROM
        get_users_with_insufficient_chrome()
);

GRANT SELECT ON app_monitoring_users_with_insufficient_chrome TO superset;
