/* In this view we regroup the metrics of:
  - sms_error_states
  - users_replication_limit
  - replication docs
*/
CREATE MATERIALIZED VIEW public.app_monitoring_sms_error_and_users_docs_replication
TABLESPACE pg_default
AS
SELECT DISTINCT ON (partner_name, reported) partner_name,
reported,
due,
muted,
failed,
delivered,
scheduled,
"users past replication_limit",
delta_of_doc
From(
    SELECT
	    COALESCE(partner_name, urls.url) AS partner_name,
        TO_DATE(created::text, 'YYYY-MM-DD') AS reported,
        COALESCE((doc #>>'{messaging,outgoing,state,due}')::int,0)as due,
        COALESCE((doc #>>'{messaging,outgoing,state,muted}')::int,0)as muted,
        COALESCE((doc #>>'{messaging,outgoing,state,failed}')::int,0)as failed,
        COALESCE((doc #>>'{messaging,outgoing,state,delivered}')::int,0)as delivered,
        COALESCE((doc #>>'{messaging,outgoing,state,scheduled}')::int,0) as scheduled,
        COALESCE((doc #>> '{replication_limit, count}')::int, 0) AS "users past replication_limit",
        COALESCE((doc #>> '{couchdb,medic,doc_count}')::int, 0) - COALESCE(lag((doc #>> '{couchdb,medic,doc_count}')::int)
            OVER (PARTITION BY docs.url_id ORDER BY created), 0) AS delta_of_doc
    FROM monitoring_docs AS docs
    INNER JOIN monitoring_urls AS urls ON (docs.url_id=urls.id)
    WHERE doctype = 'monitoring'
) AS ms
WITH DATA;

GRANT SELECT ON app_monitoring_sms_error_and_users_docs_replication to superset;

-- View indexes:
CREATE UNIQUE INDEX app_monitoring_sms_error_and_users_docs_replication_index ON public.app_monitoring_sms_error_and_users_docs_replication USING btree(partner_name, reported);
