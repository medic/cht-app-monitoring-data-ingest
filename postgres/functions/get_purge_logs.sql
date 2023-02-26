DROP FUNCTION IF EXISTS get_purge_logs();

CREATE OR REPLACE FUNCTION get_purge_logs() RETURNS TABLE(partner text, completion_date timestamptz, duration_minutes int, skipped_contacts text, error text) AS $$
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
  (doc ->> ''date'')::timestamptz as completion_date,
  ((doc ->> ''duration'')::double precision / 1000 / 60)::integer as duration_minutes,
  (doc ->> ''skipped_contacts'')::text as skipped_contacts,
  doc ->> ''error'' as error
FROM couchdb
WHERE doc #>> ''{_id}'' like ''purgelog:%''
;
            ',
            FALSE
        ) tasks(partner text, completion_date timestamptz, duration_minutes int, skipped_contacts text, error text);
END LOOP;
END;
$$ language plpgsql
;
