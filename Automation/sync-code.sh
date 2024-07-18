#!/bin/bash
set -Eeuo pipefail
set -x

cd ~/Armchair-Strategist
source ./env/bin/activate
exec > ./Automation/sync-code.log 2>&1

handle_failure() {
    error_line=$BASH_LINENO
    error_command=$BASH_COMMAND

    aws sns publish --topic-arn arn:aws:sns:us-east-2:637423600104:Armchair-Strategist --message file://./Automation/sync-code.log --subject "Code Syncing Failure - $error_line: $error_command"
}
trap handle_failure ERR
trap handle_failure SIGTERM

date
UTC=$(date)
# assume EC2 instance running from main
# shutdown dash app, ignore non-zero return status in case there is no gunicorn process running
pkill -f gunicorn || :

./Automation/auto-pull.exp -d

# relaunch dash app
gunicorn app:server -b :8000 >/dev/null 2>./Automation/dash.log &
sleep 3
pgrep gunicorn && lsof -i :8000
aws sns publish --topic-arn arn:aws:sns:us-east-2:637423600104:Armchair-Strategist --message file://./Automation/sync-code.log --subject "Code Syncing Success - $UTC"
