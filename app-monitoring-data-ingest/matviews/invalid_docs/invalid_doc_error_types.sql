DROP MATERIALIZED VIEW IF EXISTS app_monitoring_invalid_doc_errors;
CREATE MATERIALIZED VIEW app_monitoring_invalid_doc_errors AS (
    SELECT
        fn.partner AS partner_name,
        ic.partner_short_name,
        code,
        "count",
        day
    FROM
       get_doc_error_agrr() fn
    JOIN
        impactconfig ic ON fn.partner=ic.partner_name
);
GRANT SELECT ON app_monitoring_invalid_doc_errors TO superset;
