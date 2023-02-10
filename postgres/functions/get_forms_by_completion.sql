CREATE OR REPLACE FUNCTION public.get_forms_by_completion()
  RETURNS TABLE(partner text, form_name text, load_count integer, complete_count integer)
  LANGUAGE plpgsql
AS $function$
DECLARE partners CURSOR IS (
  SELECT DISTINCT ON (partner_name)
    partner_name AS name,
    port
  FROM impactconfig
  WHERE close_date IS NULL  
);
DECLARE creds record;
BEGIN 
  SELECT
    value->>'user' AS user,
    value->>'password' AS password 
  FROM configuration 
  WHERE KEY = 'dblink' 
  INTO creds;

  FOR partner IN partners LOOP RETURN query
  SELECT *
  FROM dblink(
    FORMAT(
        'dbname=%s host=localhost port=%s user=%s password=%s',
        partner.name,
        partner.port,
        creds.user,
        creds.password
    ),
        '
WITH telemetry_docs_with_metric_blob AS (
  SELECT
    doc->> ''_id'' AS id,
    concat_ws(
      ''-''::text, doc #>> ''{metadata,year}'',
      CASE
          WHEN
            doc #>> ''{metadata,day}'' IS NULL -- some telemetry documents have version 3.4, but have the modern daily metadata
            AND (
              doc #>> ''{metadata,versions,app}'' IS NULL or 
              string_to_array("substring"(doc #>> ''{metadata,versions,app}'', ''(\d+.\d+.\d+)''), ''.'')::integer[] < ''{3,8,0}''::integer[]
            )
          THEN ((doc #>> ''{metadata,month}'')::integer) + 1
          ELSE (doc #>> ''{metadata,month}'')::integer
      END,
      CASE
          WHEN (doc #>> ''{metadata,day}'') IS NOT NULL
          THEN doc #>> ''{metadata,day}''
          ELSE ''1''::text
      END
    )::date AS period_start,
    jsonb_object_keys(doc->''metrics'') AS metric,
    doc->''metrics''->jsonb_object_keys(doc->''metrics'') AS metric_values
  FROM couchdb_users_meta
  WHERE
    doc ->> ''type'' = ''telemetry''
),

telemetry_metrics AS (
  SELECT 
    id,
    period_start,
    metric,
    min,
    max,
    sum,
    count,
    sumsqr
  FROM telemetry_docs_with_metric_blob
  CROSS JOIN LATERAL jsonb_to_record(metric_values) AS (min decimal, max decimal, sum decimal, count bigint, sumsqr decimal)
)

SELECT
  current_database() AS partner,
  split_part(metric, '':'', 3) AS form_name,
  COALESCE(SUM(count) filter (WHERE metric LIKE ''%:render''), 0) AS load_count,
  COALESCE(SUM(count) filter (WHERE metric LIKE ''%:save''), 0) AS complete_count,

  
  -- this percentile is misrepresentative for any project with monthly telemetry docs
  -- same performance as percentile_disc(array[0.1, 0.5, 0.9])
  percentile_disc(0.1) within group (order by COALESCE(sum, 0) / count) filter (where metric like ''%:user_edit_time'') as completion_time_10percentile,
  percentile_disc(0.5) within group (order by COALESCE(sum, 0) / count) filter (where metric like ''%:user_edit_time'') as completion_time_50percentile,
  percentile_disc(0.9) within group (order by COALESCE(sum, 0) / count) filter (where metric like ''%:user_edit_time'') as completion_time_90percentile
FROM telemetry_metrics
WHERE
  period_start >= now() - ''60 days''::interval
  and metric LIKE ''enketo:%'' AND metric LIKE ''%:add:%''
GROUP BY 1, 2
;
        ',
        FALSE
    ) completions(partner text, form_name text, load_count integer, complete_count integer);
END LOOP;
END;
$function$
;
