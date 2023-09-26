CREATE OR REPLACE FUNCTION public.get_users_with_insufficient_chrome()
  RETURNS TABLE(partner text, user_name text, chrome_version integer, required_chrome_version integer)
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
  current_database() as partner,
  user_name,
  chrome_version,
  required_chrome_version
FROM (
  SELECT
    DISTINCT ON (user_name)
    user_name,
    CASE 
      -- https://github.com/medic/cht-core/issues/8161
	  WHEN doc #>> ''{metadata,versions,app}'' = ''unknown'' THEN 71
	  ELSE 52
	END AS required_chrome_version,
    substring(user_agent FROM ''Chrome\/(\d{2,3})'')::int AS chrome_version
  FROM useview_telemetry_devices
  LEFT JOIN couchdb_users_meta ON doc ->> ''_id'' = useview_telemetry_devices.telemetry_doc_id
  ORDER BY
    user_name ASC,
    period_start DESC 
) T
WHERE chrome_version < required_chrome_version
;
        ',
        FALSE
    ) query_result(partner text, user_name text, chrome_version integer, required_chrome_version integer);
END LOOP;
END;
$function$
;
