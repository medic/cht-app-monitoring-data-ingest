CREATE MATERIALIZED VIEW app_monitoring_feedback_docs AS
  SELECT
    uuid,
    partner AS partner_name,
    username,
    reported,
    source,
    detail
  FROM get_feedback_docs();

CREATE UNIQUE INDEX IF NOT EXISTS app_monitoring_feedback_docs_partner_name_uuid ON app_monitoring_feedback_docs  USING btree(partner_name, uuid);

GRANT SELECT ON app_monitoring_feedback_docs TO superset;