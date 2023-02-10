CREATE MATERIALIZED VIEW app_monitoring_users_replication_limit AS
    SELECT
        created,
        partner_name,
        COALESCE((doc #>> '{replication_limit, count}')::int, 0) AS "users past replication_limit"
    FROM
        monitoring_docs AS docs
    LEFT JOIN monitoring_urls AS urls ON (docs.url_id=urls.id);

CREATE UNIQUE INDEX IF NOT EXISTS app_monitoring_users_replication_limit_created_partner_name ON app_monitoring_users_replication_limit  USING btree(created, partner_name);

GRANT SELECT ON app_monitoring_users_replication_limit TO superset;