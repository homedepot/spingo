#!/bin/bash

SPINNAKER_BOT="spinnakerbot"
TOKEN_FROM_SLACK="${TOKEN_FROM_SLACK}"

%{ for deployment in deployments ~}
if [[ "$TOKEN_FROM_SLACK" != "no-slack" ]]; then
    echo "Adding Spinnaker Slack Integration for deployment named ${deployment}"
    hal config notification slack enable \
        --deployment ${deployment}
    echo "$TOKEN_FROM_SLACK" | hal config notification slack edit --deployment ${deployment} --bot-name "$SPINNAKER_BOT" --token
    echo "Added Spinnaker Slack Integration for deployment named ${deployment}"
else
    echo "No slack token found so skipping setting up Slack notifications for deployment named ${deployment}"
fi
%{ endfor ~}

echo "You will need to do a hal deploy apply to push the changes."
