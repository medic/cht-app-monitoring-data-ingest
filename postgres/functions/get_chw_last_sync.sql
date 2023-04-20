CREATE OR REPLACE FUNCTION public.get_chw_last_sync() RETURNS TABLE(partner text, chw_id text, chw_username text, last_sync date) AS $$
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
            SELECT
                current_database() as partner,
		        form.chw as chw_id,
		        c_user.doc->>''name'' as chw_username,
		        max(c_info.doc->>''latest_replication_date'') as last_sync
            FROM
		        form_metadata form
            JOIN couchdb c_info ON form.uuid=c_info.doc->>''doc_id''
            JOIN couchdb c_user ON form.chw=c_user.doc->>''contact_id''
            WHERE
		        c_info.doc->>'type' = ''info'' and c_user.doc->>''type''=''user-settings''
            GROUP BY
		        form.chw, c_user.doc->>''name'';
            ',
            FALSE
        ) result(partner text, chw_id text, chw_username text, last_sync date);
END LOOP;
END;
$$ language plpgsql;
