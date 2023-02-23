CREATE OR REPLACE VIEW app_monitoring_couchpg_backlog AS (
  SELECT 
    partner_name,
    created,
    source,
    couch_seq - couchpg_seq as couchpg_backlog
  FROM (
    SELECT
      couchpg.partner_name,
      couchpg.created AS created,
      couchpg.source AS source,
      couchpg.seq AS couchpg_seq,
      jsonb_extract_path(docs.doc, 
        'couchdb', 
        replace(replace(couchpg.source, 'medic-', ''), '-', ''),
        'update_sequence'
      )::TEXT::BIGINT as couch_seq
    FROM monitoring_couchpg couchpg
    JOIN monitoring_urls urls ON urls.partner_name = couchpg.partner_name
    JOIN monitoring_docs docs ON docs.url_id = urls.id AND couchpg.created = date_trunc('day', docs.created)
  ) T
  WHERE couch_seq IS NOT NULL
);

GRANT SELECT ON app_monitoring_couchpg_backlog TO superset;
ALTER VIEW public.app_monitoring_couchpg_backlog OWNER TO full_access;
