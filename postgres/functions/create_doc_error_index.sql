DROP FUNCTION IF EXISTS create_doc_error_index();

CREATE OR REPLACE FUNCTION create_doc_error_index() RETURNS VOID AS $$
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
        FORMAT(
            'dbname=%s host=localhost port=%s user=%s password=%s',
            partner.name,
            partner.port,
            credentials.user,
            credentials.password
        ),
        '
        CREATE INDEX IF NOT EXISTS couchdb_doc_errors_idx ON couchdb((doc->>''errors'')) WHERE doc->>''errors'' IS NOT NULL AND jsonb_array_length((doc->>''errors'')::jsonb) > 0;
        ANALYZE couchdb;
        ',
        FALSE
    );
END LOOP;
END;
$$ language plpgsql;
