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
3. Add these to you `cht-watchdog/.env` for Watchdog docker compose, being sure to replace each of the 5 values:
   ```
   EXTRA_SQL_PASS=<PASSWORD_HERE>
   EXTRA_SQL_USER=<USER_HERE>
   EXTRA_SQL_DATABASE=<DATABASE_HERE>
   EXTRA_SQL_SERVER=<IP_OR_FQDN_HERE>
   EXTRA_SQL_PORT=<PORT_HERE>
   ```
4. While in the Watchdog directory, start it with:
   ```
   docker-compose -f docker-compose.yml \
       -f exporters/postgres/docker-compose.postgres-exporter.yml \
       -f app-monitoring-data-ingest/extra-sql-compose.yml \
       up -d --remove-orphans
   ```
   
### Development install

Assuming you have a remote production Postgres server which is populated with the data you want to prototype against, here's now to set up a development environment:

1. Ensure you have a way to connect to production Postgres with a read only user from your development environment.  This may be using a VPN or an SSH tunnel.  A recipe for an SSH tunnel looks like this, assuming `ssh-user`, `postgres.example.com` and `34795` are the SSH user, server and port you can SSH to for access to the Postgres server.  Note that `172.17.0.1` is binding the service to your host's docker IP. This ensures containers can access it but doesn't expose it to the LAN:
   ```shell
   ssh -L 172.17.0.1:5432:localhost:5432 ssh-user@postgres.example.com -p 34795
   ```
2. Update your docker `.env` file to have the correct values.  Assuming you're connecting to the database `dwh_impact` with the user `postgres_user` and the password `secret_password`, this would look like:
   ```
   EXTRA_SQL_PASS=secret_password
   EXTRA_SQL_USER=postgres_user
   EXTRA_SQL_DATABASE=dwh_impact
   EXTRA_SQL_SERVER=172.17.0.1
   EXTRA_SQL_PORT=5432
   ```
3. Ensure you have followed the install steps above, including the symlinking
4. Add a new metric per below
5. Restart your containers to reload the new config


## Adding a new metric

Assuming your working on a local dev instance with read access to production database, here's the steps to port the ["Replication Failure Reasons"](https://github.com/medic/cht-app-monitoring-data-ingest/blob/main/postgres/matviews/replication_failure_reasons.sql) query from Superset to Watchdog

1. Ensure your raw SQL query works. In our example Replication Failures, after viewing the query in Superset, this would look like
   ```sql
   SELECT 
      metric AS metric,
      sum(count) AS "Count"
   FROM 
      public.app_monitoring_replication_failure_reasons
   WHERE 
      partner_name IN ('partner_name_here')
   GROUP BY 
      metric
   ORDER BY 
      "Count" DESC
   LIMIT 
      10000;   
   ```
2. So that the query can find all CHT instances as well as their URLs we need to
   * remove  `WHERE` clause
   * lookup the partner URL with a left join
   * add partner name and URL to the `SELECT`
   * clean up the URL so it doesn't have the `https://`
   ```sql
    SELECT 
      metric as failure_type,
      sum(count) AS count,
      failures.partner_name,
      replace(monitoring_urls.url, 'https://', '') as cht_instance
    FROM 
      app_monitoring_replication_failure_reasons as failures
    LEFT JOIN 
      monitoring_urls ON failures.partner_name=monitoring_urls.partner_name
    GROUP BY 
      failures.partner_name,
      failure_type,
      cht_instance
    ORDER BY 
      partner_name, count DESC
   ```
   Be sure to test this query directly in a Postgres client.  This way you're sure it works before proceeding.
3. Add this new query to `extra-sql-compose.yml`. Ensure the outermost line is a good name, like `replication_failure_reasons`, as it will show up in Grafana when you're prototyping the query. You can add as many queries as you want to this file.
4. Restart your docker containers being sure to use the same list of files you used to start it.
5. _OPTIONAL_: List the IP of your extra SQL exporter:
   ```shell
   docker inspect $(docker ps -q ) --format='{{ printf "%-50s" .Name}} {{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}'  | tr "\/" " "
   ```
   And then browse to the `/metric` endpoint on port `9187` for the `cht-watchdog-extra_sql_exporter-1` container IP (eg `http://172.30.0.5:9187/metrics`). Verify you see the results of the query you just added. They'll be at the bottom of the page.
7. In Grafana - navigate to the "Explore". In the "Metric" field, enter the name you used in step #3.
8. Format the panel as you'd like.  In a tabular format, you may have to hide many of the columns you don't wish to show.
9. Choose "Add to dashboard" at the top, select "CHT/CHT Admin Extra SQL" and choose "Open dashboard"
10. Edit the panel you just added.  On the "Label filters" choose `cht_instance` and set it equal to `$cht_instance`. This will filter the table to only show the values from the currently selected CHT instance.
11. Click the disk icon in the upper right and copy the JSON for the dashboard.
12. Open the `extra-sql-dashboard.json` file.  Delete everything and paste in the JSON in your clibpard
13. Commit the  `extra-sql-dashboard.json` and `extra-sql-queries.yml` files to this repo.
14. SSH to the production Watchdog instance and pull from this repo to get the updated SQL and JSON files.
15. Restart Watchdog's docker containers
16. THe new panels should sohw up on the existing dashboard.
