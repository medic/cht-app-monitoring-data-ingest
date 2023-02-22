-- for each partner database, pull the current seq number that couch2pg has synced to and upsert it into the monitoring_couchpg table
DROP FUNCTION IF EXISTS monitoring_ingest_couchpg_seqs();

CREATE OR REPLACE FUNCTION monitoring_ingest_couchpg_seqs() RETURNS void AS $$
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
    FOR partner IN partners LOOP
    
    INSERT INTO monitoring_couchpg(partner_name, created, seq, source)
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
'select
  current_database() as partner_name,
  date_trunc(''day'', now()) as created,
  split_part(seq, ''-'', 1) as seq,
  split_part(source, ''/'', 2) as source
from couchdb_progress;',
              FALSE
          ) couchdb_progress(partner_name text, created date, seq bigint, source text)
      ON CONFLICT ON CONSTRAINT monitoring_couchpg_idx_constraint DO NOTHING
      ;
END LOOP;
END;
$$ language plpgsql;
