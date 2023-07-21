CREATE OR REPLACE FUNCTION public.get_chw_last_sync() RETURNS TABLE(partner text, chw_id text, chw_username text, replication_date text) AS $$
DECLARE partners cursor IS (
        SELECT DISTINCT ON (partner_name)
            partner_name AS name,
            port
        FROM impactconfig
        WHERE status = 'Active'
    );
DECLARE credentials record;
BEGIN 
    SELECT value->>'user' AS user, value->>'password' AS password FROM configuration WHERE KEY = 'dblink' INTO credentials;
    FOR partner IN partners LOOP
    -- create connection
    RAISE NOTICE 'Connecting to %', partner.name;
    PERFORM dblink_connect('app_monitoring_idx', FORMAT('dbname=%s host=localhost port=%s user=%s password=%s', partner.name, partner.port, credentials.user, credentials.password));
    -- create indexes if they don't exist
    PERFORM dblink_exec('app_monitoring_idx', 'CREATE INDEX IF NOT EXISTS app_monitoring_couchdb_doc_id ON couchdb USING BTREE ((doc->>''doc_id''));');
    PERFORM dblink_exec('app_monitoring_idx', 'CREATE INDEX IF NOT EXISTS app_monitoring_couchdb_doc_contact_id ON couchdb USING BTREE ((doc->>''contact_id''));');
    PERFORM dblink_exec('app_monitoring_idx', 'CREATE INDEX IF NOT EXISTS app_monitoring_couchdb_doc_replication_date ON couchdb USING BTREE ((doc->>''latest_replication_date''));');
    -- disconnect
    PERFORM dblink_disconnect('app_monitoring_idx');
    -- return query result
    RETURN QUERY SELECT * FROM dblink(
        FORMAT('dbname=%s host=localhost port=%s user=%s password=%s', partner.name, partner.port, credentials.user, credentials.password),
            '
            SELECT
                current_database() as partner,
                form.chw as chw_id,
                c_user.doc->>''name'' as chw_username,
                c_info.doc->>''latest_replication_date'' as replication_date
            FROM
                form_metadata form
            INNER JOIN couchdb c_info ON form.uuid=c_info.doc->>''doc_id''
            INNER JOIN couchdb c_user ON form.chw=c_user.doc->>''contact_id''
            WHERE form.reported > now() - ''120 days''::interval;
            ',
            FALSE
        ) result(partner text, chw_id text, chw_username text, replication_date text);
END LOOP;
END;
$$ language plpgsql;
