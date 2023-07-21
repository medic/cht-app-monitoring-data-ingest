CREATE OR REPLACE VIEW app_monitoring_gateway_health AS (
    SELECT
        metrics.*,
        CASE
            WHEN metrics.due > 0 AND metrics.delivered = 0 THEN 'Gateway Unhealthy'
            ELSE
                'Gateway Healthy'
        END AS gateway_state,
        CASE
            WHEN metrics.due > 0 AND metrics.delivered = 0 THEN 
                (SELECT a.reported FROM get_last_sms_metric() a WHERE a.reported < metrics.reported AND a.delivered > 0 LIMIT 1)
            ELSE 
                metrics.reported
        END AS last_delivered
    FROM
        get_last_sms_metric() metrics
);

GRANT SELECT ON app_monitoring_gateway_health TO superset; 
ALTER VIEW public.app_monitoring_gateway_health OWNER TO full_access;
