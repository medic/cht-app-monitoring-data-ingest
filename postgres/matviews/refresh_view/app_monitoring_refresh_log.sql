DROP VIEW if EXISTS app_monitoring_refresh_log;
CREATE VIEW app_monitoring_refresh_log AS (
    SELECT monitoring.view_name, monitoring.start_date as last_refresh,
        now()::date - start_date::date as days_since_refresh
    FROM (
            select *,
                row_number() over (
                    partition by view_name
                    order by start_date desc
                ) rank
            from matviews_log
        ) monitoring
    WHERE view_name like 'app_monitoring_%' AND rank = 1
);
GRANT SELECT ON app_monitoring_refresh_log TO superset;