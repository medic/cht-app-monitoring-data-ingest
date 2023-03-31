DROP MATERIALIZED VIEW if EXISTS app_monitoring_users_with_insufficient_disk;
CREATE MATERIALIZED VIEW app_monitoring_users_with_insufficient_disk AS (
    SELECT
        partner AS partner_name,
        user_name,
        free_storage_mb
    FROM
        get_users_with_insufficient_disk()
);

GRANT SELECT ON app_monitoring_users_with_insufficient_disk TO superset;
