DROP FUNCTION IF EXISTS get_tasks_by_state();

CREATE OR REPLACE FUNCTION get_tasks_by_state() RETURNS TABLE(task text, partner text, ready int, draft int, cancelled int, completed int, failed int, day date) AS $$
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
                task,
                current_database() as partner,
                COUNT(s.state) FILTER ( WHERE state=''Ready'' ) as ready,
                COUNT(s.state) FILTER ( WHERE state=''Draft'' ) as draft,
                COUNT(s.state) FILTER ( WHERE state=''Cancelled'' ) as cancelled,
                COUNT(s.state) FILTER ( WHERE state=''Completed'' ) as completed,
                COUNT(s.state) FILTER ( WHERE state=''Failed'' ) as failed,
                day
            FROM (
                SELECT
                    doc->>''_id'' AS doc,
                    state,
                    (doc#>>''{emission,title}'') as task,
                    date_trunc(''day'', to_timestamp(((timestamp)::bigint / 1000)::double precision)) AS day
                FROM
                    couchdb
                CROSS JOIN LATERAL json_populate_recordset(null::record, (doc->>''stateHistory'')::json) AS (state text, timestamp bigint) 
                WHERE
                    doc->>''type''=''task'' AND to_timestamp(((doc->>''authoredOn'')::bigint / 1000)::double precision) > date_trunc(''day'', now() - (''120 days'')::interval)::timestamp
            ) s
            group by
                day, task;
            ',
            FALSE
        ) tasks(task text, partner text, ready int, draft int, cancelled int, completed int, failed int, day date);
END LOOP;
END;
$$ language plpgsql;
