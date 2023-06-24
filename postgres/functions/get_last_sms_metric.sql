DROP FUNCTION get_last_sms_metric();
CREATE OR REPLACE FUNCTION get_last_sms_metric() RETURNS TABLE(partner_name text, reported date, due int, delivered int, scheduled int) AS $$
DECLARE partners cursor IS (
        SELECT DISTINCT ON (ic.partner_name) ic.partner_name AS name FROM impactconfig ic WHERE ic.close_date is NULL
    );
BEGIN 
    FOR partner IN partners LOOP RETURN query
    select 
    	* 
    from (
	    select
	        partner.name as partner_name,
	        s.reported,
	        coalesce((s.due - s.prev_due), 0) as due,
	        coalesce((s.delivered - s.prev_delivered), 0) as delivered,
	        coalesce((s.scheduled - s.prev_scheduled), 0) as scheduled
	    from (
	        with cte as (
	            select 
	            	a.partner_name,
	                a.reported,
	                a.due,
	                a.delivered,
	                a.scheduled
	            from 
	                app_monitoring_sms_error_and_users_docs_replication a
	            where 
	                a.reported >= (now() - '14 days'::interval)::date and a.partner_name = partner.name
	            order by a.partner_name, a.reported desc
	        ) 
	        select 
	            *, 
	            lag(c.due, 1) over (order by c.reported) prev_due,
	            lag(c.delivered , 1) over (order by c.reported) prev_delivered,
	            lag(c.scheduled, 1) over (order by c.reported) prev_scheduled
	        from 
	            cte c
	    ) s
	    order by s.reported desc
    ) query
    order by query.reported desc;
END LOOP;
END;
$$ language plpgsql;
