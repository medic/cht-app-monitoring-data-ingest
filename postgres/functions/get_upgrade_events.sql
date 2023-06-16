DROP FUNCTION IF EXISTS get_upgrade_events();

CREATE OR REPLACE FUNCTION get_upgrade_events() RETURNS TABLE(partner text, core_version text, start_time timestamp, last_update_time timestamp, is_success boolean) AS $$
DECLARE partners cursor IS (
        SELECT DISTINCT ON (partner_name)
            partner_name AS name,
            port
        FROM impactconfig
        WHERE close_date IS NULL
    );
DECLARE credentials record;
BEGIN 
    SELECT value->>'user' AS user, value->>'password' AS password FROM configuration WHERE KEY = 'dblink' INTO credentials;
    FOR partner IN partners LOOP RETURN query
    SELECT
        *
    FROM dblink(
            FORMAT(
                'dbname=%s host=localhost port=%s user=%s password=%s',
                partner.name,
                partner.port,
                credentials.user,
                credentials.password
            ),
            '
WITH horti_upgrade_details AS (
  SELECT
    doc #>> ''{tombstone,build_info,version}'' AS core_version,
	doc #> ''{tombstone,log,0}'' AS start_log,
    doc #> ''{tombstone,log}'' -> jsonb_array_length(doc #> ''{tombstone,log}'') - 1 AS last_log
  FROM couchdb 
  where
    (doc ->> ''_id''::text) LIKE ''horti-upgrade%tombstone''
),

horti_upgrades AS (
  SELECT
    core_version,
    to_timestamp((start_log ->> ''datetime'')::numeric / 1000.0) AS start_time,
    to_timestamp((last_log ->> ''datetime'')::numeric / 1000.0) AS last_update_time,
    last_log #>> ''{message,key}'' = ''horti.stage.postCleanup'' AS is_success
  FROM horti_upgrade_details
),

medic_log_upgrades AS (
  SELECT
    doc #>> ''{to,version}'' AS core_version,
    to_timestamp((doc ->> ''start_date'')::numeric / 1000.0) AS start_time,
    to_timestamp((doc ->> ''updated_date'')::numeric / 1000.0) AS last_update_time,
    doc ->> ''state'' = ''finalized'' AS is_success
  FROM couchdb_medic_logs -- requires couch2pg v
  where doc ->> ''_id'' LIKE ''upgrade_log:%''
)

SELECT
  current_database() as partner,
  core_version,
  start_time,
  last_update_time,
  is_success
FROM (
  SELECT * FROM horti_upgrades
    UNION 
  SELECT * FROM medic_log_upgrades
) T
ORDER BY 2 DESC
;
            ',
            FALSE
        ) upgrade_events(partner text, core_version text, start_time timestamp, last_update_time timestamp, is_success boolean);
END LOOP;
END;
$$ language plpgsql;
