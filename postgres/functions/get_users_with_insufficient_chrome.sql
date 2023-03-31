CREATE OR REPLACE FUNCTION public.s()
  RETURNS TABLE(partner text, user_name text, chrome_version integer, required_chrome_version integer)
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
  chrome_version,
  required_chrome_version
FROM (
  SELECT
    DISTINCT ON (doc #>> ''{metadata,user}'')
    doc #>> ''{metadata,user}'' as user_name,
    CASE 
	  	WHEN string_to_array("substring"(doc #>> ''{metadata,versions,app}'', ''(\d+.\d+.\d+)''), ''.'')::integer[] < ''{4,0,0}''::integer[] THEN 53
	  	ELSE 71
	  END AS required_chrome_version,
    substring(doc #>> ''{device,userAgent}'' from ''Chrome\/(\d{2,3})'')::int AS chrome_version
  FROM couchdb_users_meta
  WHERE
    doc ->> ''type'' = ''telemetry''
  ORDER BY
    doc #>> ''{metadata,user}'' ASC,
    CONCAT_WS(
      ''-''::text, doc #>> ''{metadata,year}'',
      CASE
          WHEN
            doc #>> ''{metadata,day}'' IS NULL -- some telemetry documents have version 3.4, but have the modern daily metadata
            AND (
              doc #>> ''{metadata,versions,app}'' IS NULL or 
              string_to_array("substring"(doc #>> ''{metadata,versions,app}'', ''(\d+.\d+.\d+)''), ''.'')::integer[] < ''{3,8,0}''::integer[]
            )
          THEN (doc #>> ''{metadata,month}'')::integer + 1
          ELSE (doc #>> ''{metadata,month}'')::integer
      END,
      CASE
          WHEN (doc #>> ''{metadata,day}'') IS NOT NULL
          THEN doc #>> ''{metadata,day}''
          ELSE ''1''::text
      END
    )::date DESC 
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
