CREATE OR REPLACE FUNCTION public.get_replication_failure_reasons()
  RETURNS TABLE(partner text, metric text, count integer)
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
  metric,
  SUM(count) AS count
FROM useview_telemetry_metrics
WHERE period_start >= now() - ''60 days''::interval
    and metric like ''replication:medic:%:failure:reason:%''
GROUP BY 1, 2
;
        ',
        FALSE
    ) completions(partner text, metric text, count integer);
END LOOP;
END;
$function$;
