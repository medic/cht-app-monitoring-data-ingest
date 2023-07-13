op=`psql dwh_impact -c 'select refresh_app_monitoring_matviews();'`
result=$?
if [ $result != 0 ]
then
    curl -X POST -H 'Content-type: application/json' --data '{"text": "Refresh Failed"}' https://hooks.slack.com/services/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
fi

# See README for cron configuration
