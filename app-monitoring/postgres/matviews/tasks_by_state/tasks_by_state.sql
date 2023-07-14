DROP MATERIALIZED VIEW if EXISTS app_monitoring_tasks_by_state;
CREATE MATERIALIZED VIEW app_monitoring_tasks_by_state AS (
    SELECT
        fn.partner AS partner_name,
        ic.partner_short_name,
        fn.cancelled,
        fn.completed,
        fn.draft,
        fn.ready,
        fn.failed,
        fn.day,
        fn.task
    FROM
        get_tasks_by_state() fn
    JOIN
        impactconfig ic ON fn.partner=ic.partner_name
);
GRANT SELECT ON app_monitoring_tasks_by_state TO superset;
