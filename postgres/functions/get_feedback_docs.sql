DROP FUNCTION IF EXISTS get_feedback_docs();

CREATE OR REPLACE FUNCTION get_feedback_docs() RETURNS TABLE(uuid TEXT, partner TEXT, reported DATE, source TEXT, username TEXT, detail TEXT) AS $$
DECLARE partners cursor IS (
        SELECT
          partner_name AS name,
          port
        FROM impactconfig
        WHERE close_date IS NULL
    );
DECLARE credentials record;
BEGIN
SELECT value->>'user' AS user, value->>'password' AS password FROM configuration WHERE key='dblink' INTO credentials;
FOR partner IN partners LOOP RETURN query
  SELECT
      *
  FROM dblink(
          FORMAT(
              'dbname=%s host=localhost port=%s user=%s password=%s',
              partner.name, partner.port, credentials.user, credentials.password
          ),
          '
          SELECT
            doc->>''_id'' AS uuid,
            current_database() as partner,
            (doc#>>''{meta,time}'')::DATE AS reported,
            doc#>>''{meta,source}'' AS source,
            doc#>>''{meta,user,name}'' AS username,
            CONCAT(
              ''<pre>'',
              CASE
                WHEN doc#>>''{info, message}'' IS NULL
                THEN doc ->> ''info''
                ELSE doc#>>''{info, message}''
              END,
              ''</pre>''
            ) AS detail
          FROM couchdb_users_meta
          WHERE
            doc ->> ''type'' = ''feedback''
          '::TEXT,
          FALSE
      ) feedback_documents(uuid TEXT, partner TEXT, reported DATE, source TEXT, username TEXT, detail TEXT);
  END LOOP;
END;
$$ language plpgsql;