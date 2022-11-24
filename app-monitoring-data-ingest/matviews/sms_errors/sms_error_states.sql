drop materialized view if exists app_monitoring_sms_error_states;
create materialized view app_monitoring_sms_error_states as (
    SELECT COALESCE(mu.partner_name, mu.url) as partner_name,
        date_trunc(
            'day',
            to_timestamp(
                (
                    (md.doc::jsonb#>>'{date,current}')::bigint / 1000
                )::double precision
            )
        )::DATE AS reported,
        COALESCE(
            (md.doc::jsonb#>>'{messaging,outgoing,state,due}')::int,
            0
        ) as due,
        COALESCE(
            (
                md.doc::jsonb#>>'{messaging,outgoing,state,muted}'
            )::int,
            0
        ) as muted,
        COALESCE(
            (
                md.doc::jsonb#>>'{messaging,outgoing,state,failed}'
            )::int,
            0
        ) as failed,
        COALESCE(
            (
                md.doc::jsonb#>>'{messaging,outgoing,state,delivered}'
            )::int,
            0
        ) as delivered,
        COALESCE(
            (
                md.doc::jsonb#>>'{messaging,outgoing,state,scheduled}'
            )::int,
            0
        ) as scheduled
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
            FROM monitoring_docs WHERE doctype = 'monitoring'
        ) md
        JOIN monitoring_urls mu ON md.url_id = mu.id
    WHERE md.rank = 1
);
GRANT SELECT ON app_monitoring_sms_error_states TO superset;