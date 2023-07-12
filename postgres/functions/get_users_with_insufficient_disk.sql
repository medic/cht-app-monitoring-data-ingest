CREATE OR REPLACE FUNCTION public.get_users_with_insufficient_disk()
  RETURNS TABLE(partner text, user_name text, free_storage_mb integer)
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
  DISTINCT ON (user_name)
  current_database() as partner,
  user_name,
  storage_free::bigint / 1000000 as free_storage_mb
FROM useview_telemetry_devices 
WHERE storage_free::bigint / 1000000 <= 250
ORDER BY
  user_name ASC,
  period_start DESC 
;
        ',
        FALSE
    ) query_result(partner text, user_name text, free_storage_mb integer);
END LOOP;
END;
$function$
;
