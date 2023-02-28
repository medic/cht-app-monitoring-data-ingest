/* In this view we regroup the metrics of:
  - sms_error_states
  - users_replication_limit
  - replication docs
*/
CREATE MATERIALIZED VIEW public.app_monitoring_sms_error_and_users_docs_replication
TABLESPACE pg_default
AS
WITH sms_error_states AS (
SELECT COALESCE(mu.partner_name, mu.url) AS partner_name,
        date_trunc(
            'day',
            to_timestamp(
                (
                  (md.doc::jsonb#>>'{date,current}')::bigint / 1000
                )::double precision
            )
        )::date AS reported,
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
                    )::date
                    ORDER BY doc::jsonb#>>'{date,current}'
            ) AS rank
            FROM monitoring_docs WHERE doctype = 'monitoring'
        ) AS md
        JOIN monitoring_urls AS mu ON md.url_id = mu.id
    WHERE md.rank = 1
)
  SELECT
    sms.partner_name,
    sms.reported,
    sms.due,
    sms.muted,
    sms.failed,
    sms.delivered,
    sms.scheduled,
    COALESCE((doc #>> '{replication_limit, count}')::int, 0) AS "users past replication_limit",
    COALESCE((doc #>> '{couchdb,medic,doc_count}')::int, 0) - COALESCE(lag((doc #>> '{couchdb,medic,doc_count}')::int)
        OVER (PARTITION BY docs.url_id ORDER BY created), 0) AS dalta_of_doc
  FROM monitoring_docs AS docs
  INNER JOIN monitoring_urls AS urls ON (docs.url_id=urls.id)
  JOIN sms_error_states AS sms ON urls.partner_name = sms.partner_name AND TO_DATE(created::text, 'YYYY-MM-DD') = sms.reported
  WHERE doctype = 'monitoring'
WITH DATA;

GRANT SELECT ON app_monitoring_sms_error_and_users_docs_replication to superset;

-- View indexes:
CREATE UNIQUE INDEX app_monitoring_sms_error_and_users_docs_replication_index ON public.app_monitoring_sms_error_and_users_docs_replication USING btree(partner_name, reported);
