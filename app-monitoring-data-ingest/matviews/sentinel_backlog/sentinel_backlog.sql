DROP MATERIALIZED VIEW IF EXISTS app_monitoring_sentinel_backlog;
CREATE MATERIALIZED VIEW app_monitoring_sentinel_backlog AS (
    SELECT COALESCE(mu.partner_name, mu.url) as partner_name,
        date_trunc(
            'day',
            to_timestamp(
                (
                    (md.doc::jsonb#>>'{date,current}')::bigint / 1000
                )::double precision
            )
        )::DATE AS reported,
        (doc#>>'{sentinel,backlog}')::bigint as sentinel_backlog
    FROM (
            SELECT url_id,
                doc,
                ROW_NUMBER() OVER (
                    PARTITION BY url_id,
                    date_trunc(
                        'day',
                        to_timestamp(
                            (
                                (doc::jsonb#>>'{date,current}')::bigint / 1000
                            )::double precision
                        )
                    )::DATE
                    ORDER BY doc::jsonb#>>'{date,current}'
                ) rank
            FROM monitoring_docs
            WHERE doctype = 'monitoring'
        ) md
        JOIN monitoring_urls mu on md.url_id = mu.id
    WHERE md.rank = 1
);
GRANT SELECT ON app_monitoring_sentinel_backlog TO superset;