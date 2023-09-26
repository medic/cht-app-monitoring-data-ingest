CREATE OR REPLACE FUNCTION public.get_initial_replications()
  RETURNS TABLE(partner text, date date, count_initial_replications integer)
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
WITH dates AS (
  SELECT generate_series(now() - ''60 days''::interval, now(), ''1 day''::interval)::date AS date
)

SELECT
  current_database() as partner,
  dates.date,
  COALESCE(
    COUNT(*) FILTER(WHERE device_id IS NOT NULL)
  , 0) AS count_initial_replications
FROM dates	
LEFT JOIN useview_telemetry_devices ON dates.date = period_start
GROUP BY 1, 2
ORDER BY 1, 2 ASC
;
        ',
        FALSE
    ) completions(partner text, date date, count_initial_replications integer);
END LOOP;
END;
$function$
;


