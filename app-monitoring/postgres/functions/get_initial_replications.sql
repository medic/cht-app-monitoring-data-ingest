CREATE OR REPLACE FUNCTION public.get_initial_replications()
  RETURNS TABLE(partner text, date date, count_initial_replications integer)
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
WITH useview_telemetry_devices AS (
  SELECT
    DISTINCT ON (doc #>> ''{metadata,deviceId}'', doc #>> ''{metadata,user}'')
    doc #>> ''{metadata,deviceId}'' AS device_id,
    doc #>> ''{metadata,user}'' AS user_name,
    
    concat_ws(
      ''-'',
      doc #>> ''{metadata,year}'',
      CASE
        WHEN 
          doc #>> ''{metadata,day}'' IS NULL 
          AND (
            doc #>> ''{metadata,versions,app}'' IS NULL 
            OR string_to_array("substring"(doc #>> ''{metadata,versions,app}'', ''(\d+.\d+.\d+)''), ''.'')::integer[] < ''{3,8,0}''::integer[]
          ) 
        THEN (doc #>> ''{metadata,month}'')::integer + 1
        ELSE (doc #>> ''{metadata,month}'')::integer
      END,
      CASE
        WHEN doc #>> ''{metadata,day}'' IS NOT NULL 
        THEN doc #>> ''{metadata,day}''
        ELSE ''1''
      END
    )::date AS period_start
  FROM couchdb_users_meta
  WHERE doc ->> ''type'' = ''telemetry''
  ORDER BY 1, 2, 3 ASC
),

dates AS (
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


