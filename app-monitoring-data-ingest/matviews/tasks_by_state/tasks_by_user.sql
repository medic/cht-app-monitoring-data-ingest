DROP MATERIALIZED VIEW if EXISTS app_monitoring_tasks_by_user;
CREATE MATERIALIZED VIEW app_monitoring_tasks_by_user AS (
    SELECT
        fn.partner AS partner_name,
        ic.partner_short_name,
        fn.docs,
        fn.cancelled,
        fn.completed,
        ((fn.cancelled::double precision / fn.docs::double precision) * 100)::int as cancelled_perc,
        ((fn.completed::double precision / fn.docs::double precision) * 100)::int as completed_perc,
        fn.chw,
        fn.task
    FROM
        get_tasks_by_user() fn
    JOIN
        impactconfig ic ON fn.partner=ic.partner_name
);
GRANT SELECT ON app_monitoring_tasks_by_user TO superset;
