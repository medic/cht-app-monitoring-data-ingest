# CHT App Monitoring Data Ingestion

## Purpose

Scrapes data from CHT instances and ingests in Postgres. The resulting data powers our App Monitoring dashboards and can answer questions like:

* How many projects are running cht-core version 2.x or 3.x? How many are on the latest version?
* Which projects are using declarative config?
* Which projects use outbound push? How many projects enable the death_reporting transition?
* How many users have the can_logout permission? 
* How many production deployments happened this month? How many forms changed in production this month?
* How have data from the monitoring API changed over time?
* Which projects upgraded this month?

## Configuration

### Database

You will need an instance of `postgres` available and a username and password with access to a database that has these tables:

```sql
CREATE TABLE public.monitoring_urls (
    id SERIAL PRIMARY KEY,
    url VARCHAR NOT NULL,
    partner_name text,
    enabled BOOLEAN NOT NULL DEFAULT true,
    access_level smallint NOT NULL DEFAULT 1
);

CREATE TABLE public.monitoring_docs (
    id SERIAL PRIMARY KEY,
    url_id INTEGER NOT NULL,
    doctype VARCHAR NOT NULL,
    created TIMESTAMP DEFAULT NOW(),
    doc JSONB NOT NULL
);
```

Medic App Services teammates should use the `postgres/db_schema.sql` instead of the above schema.

After you have created the tables above, the list of CHT instances to scrape is controlled via the Postgres table `monitoring_urls`:

* To add a new instance, insert a row into the table
* To disable an instance, set `enabled` to `false`
* To scrape deep metrics for an instance, set `access-level` to `1`, `2`, `3` or `4`

### Credentials

Credentials to write to the `monitoring_docs` table and read from the `monitoring_urls` us set with these 5 environment variables.  The `MONITORING_USERNAME` and `MONITORING_PASSWORD` variables are shared and used to log in to all CHT instances.  You therefore need to set the same username and password for all CHT instances you want to monitor using authenticated logins. 

If you are only using `access_level` of `1`, you do not need to set `MONITORING_USERNAME` and `MONITORING_PASSWORD` as the [CHT monitoring API](https://docs.communityhealthtoolkit.org/apps/reference/api/#get-apiv1monitoring) does not require any authentication.

Environment Variable | Description | Example
-- | -- | --
PG_PORT | Port for Postgres connection | `5432`
PG_USERNAME | Username for Postgres connection | `postgres`
PG_PASSWORD | Password for Postgres connection | `abc123`
PG_HOST | Host for Postgres connection | `localhost`
PG_DATABASE | Database for Postgres connection | `dwh_impact`
MONITORING_USERNAME | Username on CHT instances with monitoring permissions | `app-monitor`
MONITORING_PASSWORD | Password for CHT MONITORING_USERNAME | `abc123`

Copy the `.env.example` file to `.env` and edit it with your deployment's values.  It will look something like this:

```env
PG_PORT=5432
PG_USERNAME=postgres
PG_PASSWORD=abc123
PG_HOST=localhost
PG_DATABASE=impact
MONITORING_USERNAME=app-monitor
MONITORING_PASSWORD=app-monitor
```

You can then use this file for both `docker` and `node` based deployments. 

### Accessing remote Postgres instances

If you need to access a Postgres instance via an SSH tunnel, consider 
[using `autossh`](https://github.com/Autossh/autossh).  This can be installed with `apt` or `snap` on Ubuntu and will
ensure the tunnel is up at all times to ensure consistent access to Postgres.

If you need to access a remote Postgres instance from inside a `docker` container over an SSH tunnel, consider 
binding the tunnel to the `docker` subnet, which is normally a `/16` and is often `172.17.0.1/16`.  This might look like:

```shell
ssh -L 172.17.0.1:5432:localhost:5432 username@remote.db-server.org 
```

You would then set `PG_HOST` to `172.17.0.1` and it will be accessible to all containers.  See 
[this blog post](https://www.stefanproell.at/posts/2020-07-26-ssh-tunnel-docker/) for more info.  `autossh` can be used
in combination with this technique.

## Execution

Both the `node` and `docker` versions need to be run on a schedule, as natively the app will run once and quit.  Consider [using
`cron`](https://en.wikipedia.org/wiki/Cron).

### Node

1. Ensure you have `node` and `npm` installed ( `nvm` is [an easy way](https://github.com/nvm-sh/nvm#installing-and-updating)). 
2. Confirm  `node` and `npm` are installed with `node -v&&npm -v`
3. Clone this repo and `cd` into the `app-monitoring-data-ingest` directory
4. Install dependencies with `npm ci`
5. Set your environment vars with `source .env`
6. Running the app with `node .`

### Docker

For a fully docker based deployment, you can set up [CHT couch2pg](https://github.com/medic/cht-couch2pg) first, and then add a database and schema from above to the Postgres instance.

After you have set up your `.env` per above, run `docker-compose up`.  All related should be built and downloaded as needed.

## Output

As the `access-level` of the user increases from `1` up to `4`, richer metrics are available. The results of the scraped data are stored in Postgres tables:

table | doctype | description
-- | -- | --
monitoring_docs | settings | [app_settings.json](https://docs.communityhealthtoolkit.org/apps/reference/app-settings/)
monitoring_docs | monitoring | Result from [Monitoring API v1](https://docs.communityhealthtoolkit.org/apps/reference/api/#get-apiv1monitoring)
monitoring_docs | analysis | See [Analysis](#analysis)
monitoring_docs | error | An error occurred while scraping the instance. Document contains error
monitoring_logs | - | [Purging logs and errors](https://docs.communityhealthtoolkit.org/apps/guides/performance/purging/#purged-documents-server-side)
monitoring_couchpg | - | The status of couch2pg's sync for each couch database 

### Access Level 1

Access Level | Access Requirement | Output
-- | -- | --
1 | Anonymous | Monitoring API Only
2 | Offline User | Basic (Analysis)[#analysis]
3 | Online User | Full (Analysis)[#analysis]
4 | Access to Sentinel Logs | Purging logs

### Access Level 2

1. Login as administrator
2. Create new doc in `_users` database

```
{
  "_id": "org.couchdb.user:app-monitoring",
  "name": "app-monitoring",
  "type": "user",
  "roles": ["app_monitoring"],
  "password": "abc123"
}
```

3. Create new doc in `medic` database

```
{
  "_id": "org.couchdb.user:app-monitoring",
  "name": "app-monitoring",
  "type": "user-settings",
  "roles": ["app_monitoring"]
}
```

### Access Level 3

Access Level `2` but add role `mm-online`. This gives the user access to all data on the instance.

### Access Level 4

Access Level `3` and alter `/medic-sentinel/_security` setting `members.roles` to include `app_monitoring`. 

### Analysis

This is the structure of documents in `monitoring_docs` with `doctype='analysis'`:

Metric | Description
-- | --
url | If you don't know what this is, this is the wrong dataset for you
status | `ok` if scraped. Otherwise, the error that prevented scraping
numberOfUsers | How many users in the _users database (Access Level 3 required)
numberOfRoles | How many roles configured in app_settings
numberOfOfflineUser | How many users have a role with `offline: true` (Access Level 3 required)
isDeclarativeConfig | True if the project is using declarative configuration
numberOfConfigurableHierarchyContactTypes | Number of configured contact_types in app_settings which are not the defaults (`person`, `clinic`, etc)
enabledPurging | True if the project has a purge function
dhisDataSourceCount | Number of elements in `app_settings.dhis_data_sets`
uhcEnabled | Is `app_settings.uhc.visit_count` enabled
numberOfAppForms | Number of app forms uploaded to the project
numberOfContactForms | Number of contact forms uploaded to the project
numberOfTargets | The number of configured targets `app_settings.tasks.targets.items.length`
numberOfTaskSchedulesNonDeclarative | The nubmer of configured task schedules (only works for non-declarative projects) `settings.tasks.schedules`
countOfJsonRegistrations | `app_settings.registrations.length`
countOfJsonPatient_reports | `app_settings.patient_reports.length`
countOfJsonReplications | `app_settings.replications.length`
countOfJsonSchedules | `app_settings.schedules.length`
countOfJsonForms | `Object.keys(app_settings.forms).length`
countOfOutboundPushes | `Object.keys(app_settings.outbound).length`
appSettingRevs | Number of revisions to the `settings` document. This number changes each time `medic-conf upload-app-settings` has an effect
formRevs | Number of revisions to form documents. This number changes once per form each time `medic-conf upload-app-forms upload-contact-forms` has an effect
permission.* | Number of users with this permission (Access Level 3 required)
transitions.* | True if the transition is enabled for this project
