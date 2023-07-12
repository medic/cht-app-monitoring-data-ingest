CREATE OR REPLACE FUNCTION public.get_replication_by_status()
  RETURNS TABLE(partner text, period_start date, replication_success_count integer, replication_failure_count integer, replication_denied_count integer, replication_error_count integer)
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
SELECT
  current_database() AS partner,
  period_start,
  COALESCE(SUM(count) filter(where metric LIKE ''%:medic:%:success''), 0) AS replication_success_count,
  COALESCE(SUM(count) filter(where metric LIKE ''%:medic:%:failure''), 0) AS replication_failure_count,
  COALESCE(SUM(count) filter(where metric LIKE ''%:medic:%:denied''), 0) AS replication_denied_count,
  COALESCE(SUM(count) filter(where metric LIKE ''%:failure:reason:error''), 0) AS replication_error_count
FROM useview_telemetry_metrics
WHERE
  period_start >= now() - ''60 days''::interval
  and metric like ''replication:%''
GROUP BY 1, 2
;
        ',
        FALSE
    ) completions(partner text, period_start date, replication_success_count integer, replication_failure_count integer, 	replication_denied_count integer, replication_error_count integer);
END LOOP;
END;
$function$;
