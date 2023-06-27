CREATE OR REPLACE VIEW app_monitoring_gateway_health AS (
    SELECT
        *,
        CASE
            WHEN due > 0 AND delivered = 0 THEN 'Gateway Unhealthy'
            ELSE
                'Gateway Healthy'
        END AS gateway_state
    FROM
        get_last_sms_metric()
);

GRANT SELECT ON app_monitoring_gateway_health TO superset; 
ALTER VIEW public.app_monitoring_gateway_health OWNER TO full_access;
