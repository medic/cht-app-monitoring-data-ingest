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
    CASE
      --https://github.com/medic/cht-core/issues/7113
      WHEN doc #>> '{version,app}' ~ '^\d*\.\d*\.\d*$' AND regexp_split_to_array((doc#>>'{version,app}'), '\.')::int[] < '{3,12,0}'::int[]
      THEN NULL::bigint

      -- https://github.com/medic/cht-core/issues/8162
      WHEN doc #>> '{version,app}' ~ '^\d*\.\d*\.\d*$' AND regexp_split_to_array((doc#>>'{version,app}'), '\.')::int[] = '{4,1,0}'::int[]
      THEN NULL::bigint
      
      ELSE (doc#>>'{sentinel,backlog}')::bigint
    END as sentinel_backlog
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