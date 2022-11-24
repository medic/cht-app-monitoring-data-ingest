CREATE OR REPLACE FUNCTION public.refresh_app_monitoring_matviews()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  matview RECORD;
BEGIN
  FOR matview IN SELECT matviewname FROM pg_catalog.pg_matviews where matviewname like 'app_monitoring%' LOOP
    RAISE NOTICE 'Refreshing %', matview.matviewname;
    EXECUTE format('REFRESH MATERIALIZED VIEW %I', matview.matviewname);
    EXECUTE format('INSERT INTO matviews_log VALUES (''%I'', ''R'', now());', matview.matviewname);
  END LOOP;
  RAISE NOTICE 'Materialized views refreshed.';
  RETURN 1;
END;
$function$;
