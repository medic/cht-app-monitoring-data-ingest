CREATE OR REPLACE FUNCTION public.get_forms_by_completion()
  RETURNS TABLE(partner text, form_name text, load_count integer, complete_count integer)
  LANGUAGE plpgsql
AS $function$
DECLARE partners CURSOR IS (
  SELECT DISTINCT ON (partner_name)
    partner_name AS name,
    port
  FROM impactconfig
  WHERE status = 'Active'  
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
FROM useview_telemetry_metrics
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
