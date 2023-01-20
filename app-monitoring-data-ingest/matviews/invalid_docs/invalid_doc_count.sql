DROP MATERIALIZED VIEW if EXISTS app_monitoring_invalid_docs;
CREATE MATERIALIZED VIEW app_monitoring_invalid_docs AS (
    SELECT
        fn.partner AS partner_name,
        ic.partner_short_name,
        fn.invalid_doc_count,
        fn.day
    FROM
        get_invalid_doc_count() fn
    JOIN
        impactconfig ic ON fn.partner=ic.partner_name
);
GRANT SELECT ON app_monitoring_invalid_docs TO superset;
