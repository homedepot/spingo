#!/bin/bash

die() { echo "$*" 1>&2 ; exit 1; }

kill_port(){
        while true
        do
        echo "Attempting to kill port $1"
            fuser -k "$1"/tcp >/dev/null 2>&1
            if [[ "$?" -ne 0 ]]; then
            echo "port $1 killed"
            break
            fi
        done
}

forward_port(){
    SVC_NAME="$1"
    SERVICE_PORT="$2"
    kill_port "$SERVICE_PORT"
    echo "patching fiat to add serice account for groups"
    kubectl port-forward service/spin-"$SVC_NAME" "$SERVICE_PORT":"$SERVICE_PORT" -n spinnaker >/dev/null 2>&1 &
    echo "pause for 2 seconds to wait for connection"
    sleep 2
}

while test $# -gt 0; do
  case "$1" in
    -h|--help)
      echo "Usage: $0 -r|--role <role> (usually a group or team)"
      exit
      ;;
    -r|--role)
      test ! -z $2 && ROLE=$2
      shift
      ;;
    *)
      shift
      ;;
  esac
done

if [[ -z "$ROLE" ]]; then
    die "You must specify a role -r|--role <role> (usually a group or team)"
fi

FIAT_PORT="7003"
FRONT50_PORT="8080"
FRONT50="http://localhost:$FRONT50_PORT"
FIAT="http://localhost:$FIAT_PORT"

forward_port "fiat" "$FIAT_PORT"
forward_port "front50" "$FRONT50_PORT"

curl -X POST \
    -H "Content-type: application/json" \
    -d '{ "name": "'"$ROLE"'_member", "memberOf": ["'"$ROLE"'"] }' \
    "$FRONT50"/serviceAccounts

if [[ "$?" -ne 0 ]]; then
    echo "Unable to create fiat service account for $ROLE"
    exit 1
else
    echo "Created fiat service account within front50 of $${ROLE}_member for role $ROLE"
fi

# force fiat to sync the change
curl -X POST "$FIAT"/roles/sync

if [[ "$?" -ne 0 ]]; then
    echo "Unable to sync front50 roles for $ROLE"
    exit 1
else
    echo "Synced roles within fiat for $ROLE"
fi

kill_port "$FRONT50_PORT"
kill_port "$FIAT_PORT"

echo "Fiat service account creation complete"
