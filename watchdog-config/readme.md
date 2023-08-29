# CHT Watchdog config files

These files will allow a [CHT Watchdog](https://github.com/medic/cht-watchdog/) instance to easily query the Data Warehouse database (`dwh_impact`) that the CHT App Monitoring Data Ingestion writes to.

The overall goal is to reproduce the Superset dashboard in a CHT Watchdog instance.  This will largely mean reproducing [the original queries](https://github.com/medic/cht-app-monitoring-data-ingest/tree/main/postgres/matviews) in a Prometheus comptabible YAML file(s).

## Install

Assuming you have:
* A Watchdog instance installed and running with a `cht-instances.yml` populated
* Have a Postgress database populated with both `couch2pg` data for each CHT instance AND a database with the queries from this repo running
* Have a Postgress user Watchdog can use to query both databases from above point

You would:
1. Check out this repo so it's next to where `cht-watchdog` is checked out 
2. Symlink in `watchdog-config` form this repo to base of `cht-watchdog` repo:
   ```
   ln -s cht-app-monitoring-data-ingest/watchdog-config cht-watchdog/app-monitoring-data-ingest
   ```
4. Add these to you `cht-watchdog/.env` for Watchdog docker compose, being sure to replace each of the 5 values:
   ```
   EXTRA_SQL_PASS=<PASSWORD_HERE>
   EXTRA_SQL_USER=<USER_HERE>
   EXTRA_SQL_DATABASE=<DATABASE_HERE>
   EXTRA_SQL_SERVER=<IP_OR_FQDN_HERE>
   EXTRA_SQL_PORT=<PORT_HERE>
   ```
5. While in the Watchdog directory, start Watchdog with:
   ```
   docker-compose  -f app-monitoring-data-ingest/extra-sql-compose.yml -f exporters/postgres/docker-compose.postgres-exporter.yml -f docker-compose.yml up -d   --remove-orphans
   ```

## Adding a new metric

1. Find the [the original query](https://github.com/medic/cht-app-monitoring-data-ingest/tree/main/postgres/matviews)
2. Update `extra-sql-queries.yml`, being sure to add `LEFT JOIN monitoring_urls ON failures.partner_name=monitoring_urls.partner_name` so that we can match the URL to the partner name
3. Test locally and manually build out the dashboard
4. Save the changes to `extra-sql-dashboard.json`
5. Push live and restart CHT Watchdog with new changes
