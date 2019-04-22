#!/bin/bash

SPINNAKER_BOT="spinnakerbot"
TOKEN_FROM_SLACK="${TOKEN_FROM_SLACK}"

hal config notification slack enable
echo "$TOKEN_FROM_SLACK" | hal config notification slack edit --bot-name "$SPINNAKER_BOT" --token

echo "You will need to do a hal deploy apply to push the changes."
