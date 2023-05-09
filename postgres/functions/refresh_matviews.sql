CREATE OR REPLACE FUNCTION public.refresh_app_monitoring_matviews()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  matview RECORD;
  start_time timestamp with time zone;
BEGIN
  start_time := transaction_timestamp();
  FOR matview IN SELECT matviewname FROM pg_catalog.pg_matviews where matviewname like 'app_monitoring%' LOOP
    RAISE NOTICE 'Refreshing %', matview.matviewname;
    EXECUTE format('REFRESH MATERIALIZED VIEW %I', matview.matviewname);
    EXECUTE format('INSERT INTO matviews_log(view_name, create_or_refresh, start_date, elapsed_time) VALUES (''%I'', ''R'', now(), ''%s'');', matview.matviewname, clock_timestamp() - start_time);
  END LOOP;
  RAISE NOTICE 'Materialized views refreshed.';
  RETURN 1;
END;
$function$;
