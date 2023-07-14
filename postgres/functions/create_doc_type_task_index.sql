DROP FUNCTION IF EXISTS create_doc_type_task_index();

CREATE OR REPLACE FUNCTION create_doc_type_task_index() RETURNS VOID AS $$
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
    PERFORM dblink(
        format(
            'dbname=%s host=localhost port=%s user=%s password=%s',
            partner.name,
            partner.port,
            credentials.user,
            credentials.password
        ),
        '
        CREATE INDEX IF NOT EXISTS couchdb_doc_type_task_authored_on ON couchdb(to_timestamp(((doc->>''authoredOn'')::bigint / 1000)::double precision), (doc#>>''{emission,title}''), (doc->>''type'')) WHERE doc->>''type''=''task'';
        ANALYZE couchdb;
        ',
        FALSE
    );
END LOOP;
END;
$$ language plpgsql;
