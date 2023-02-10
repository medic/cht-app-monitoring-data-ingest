DROP FUNCTION IF EXISTS get_doc_error_agrr();

CREATE OR REPLACE FUNCTION get_doc_error_agrr() RETURNS TABLE(partner text, code text, count int, day date) AS $$
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
                code,
                count(code),
                date_trunc(''day'', to_timestamp(((doc ->> ''reported_date'')::bigint / 1000)::double precision))::DATE as day
            FROM
                couchdb
            CROSS JOIN LATERAL json_populate_recordset(null::record, (doc->>''errors'')::json) AS (code text, message text)
            WHERE
                doc->>''type'' = ''data_record'' AND doc->>''errors'' IS NOT NULL AND jsonb_array_length((doc->>''errors'')::jsonb) > 0 
                AND date_trunc(''day'', to_timestamp(((doc ->> ''reported_date'')::bigint / 1000)::double precision)) > date_trunc(''day'', now() - (''120 days'')::interval)
            GROUP BY
                code,
                day
            ',
            FALSE
        ) doc_error(partner text, code text, count int, day date);
END LOOP;
END;
$$ language plpgsql;
