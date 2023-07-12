DROP FUNCTION IF EXISTS get_tasks_by_user();

CREATE OR REPLACE FUNCTION get_tasks_by_user() RETURNS TABLE(chw text, task text, partner text, docs int, cancelled int, completed int) AS $$
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
    s.chw,
    s.task,
    current_database() as partner,
    count(s.state) as docs,
    count(s.state) filter ( where state=''Cancelled'' ) as cancelled,
    count(s.state) filter ( where state=''Completed'' ) as completed
FROM (
    SELECT 
        doc->>''user'' as chw,
        doc#>>''{emission,contact,name}'' as contact,
        doc#>>''{state}'' as state,
        (doc#>>''{emission,title}'') as task,  
        date_trunc(''day'', to_timestamp((doc ->> ''authoredOn'')::bigint / 1000)) AS day
    FROM 
        couchdb
    WHERE 
        doc ->> ''type'' = ''task''
        AND (doc ->> ''authoredOn'')::double precision / 1000 >= extract(epoch from date_trunc(''day'', now() - ''60 days''::interval))
) s
GROUP BY
    chw, task;
            ',
            FALSE
        ) tasks(chw text, task text, partner text, docs int, cancelled int, completed int);
END LOOP;
END;
$$ language plpgsql;
