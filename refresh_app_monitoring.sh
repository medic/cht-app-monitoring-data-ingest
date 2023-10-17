op=`psql dwh_impact -c 'select refresh_app_monitoring_matviews();'`
result=$?
if [ $result != 0 ]
then
    curl -X POST -H 'Content-type: application/json' --data '{"text": "Refresh Failed"}' $SLACK_HOOK_URL

# See README for cron configuration
