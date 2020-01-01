#!/bin/bash

CWD=$(pwd)
GIT_ROOT_DIR=$(git rev-parse --show-toplevel)
cd "$GIT_ROOT_DIR" || { echo "failed to change directory to $GIT_ROOT_DIR exiting"; exit 1; }

. scripts/common.sh

setup_and_run_tf(){
    DIR="$GIT_ROOT_DIR/$1"
    cd "$DIR" || { echo "cd to $DIR failed. Unable to run terraform commands. Cowardly exiting" ; return; }
    n=0
    until [ $n -ge 20 ]
    do
        ATTEMPT="success"
        terraform init && break
        ATTEMPT="fail"
        n=$[$n+1]
        echo "Unable to initialize terraform directory $DIR retrying..."
        sleep 6
    done
    if [ "$ATTEMPT" == "fail" ]; then
        echo "terraform init of $DIR failed. Unable to run terraform commands. Cowardly exiting"
        exit 1
    fi
    n=0
    until [ $n -ge 20 ]
    do
        ATTEMPT="success"
        terraform apply -auto-approve && break
        ATTEMPT="fail"
        n=$[$n+1]
        echo "Unable to run apply command on terraform directory $DIR retrying..."
        sleep 6
    done
    if [ "$ATTEMPT" == "fail" ]; then
        echo "terraform apply -auto-approve of $DIR failed. Unable to run terraform commands. Cowardly exiting"
        exit 1
    fi
}

while test $# -gt 0; do
  case "$1" in
    -h|--help)
      echo "Usage: $0 -s|--skip-initial-setup to skip initial setup"
      exit
      ;;
    -s|--skip-initial-setup)
      SKIP_INITIAL_SETUP="true"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

if [ "$SKIP_INITIAL_SETUP" == "true" ]; then
    echo "Skipping initial setup at user request"
else
    if ! ./scripts/initial_setup.sh
    then
        echo "Initial setup failed so cowardly exiting"
        exit 1
    fi
fi

setup_and_run_tf "dns"
DNS_HOSTNAME=$(terraform output google_dns_managed_zone_hostname)
DIG_CHECK=$(dig "$DNS_HOSTNAME" ns +short)
if [ "$DIG_CHECK" == "" ]; then
    echoerr "-----------------------------------------------------------------------------"
    echoerr " *****   Google Cloud DNS Setup ***** Setup instructions can be found here https://github.com/homedepot/spingo#setup-managed-dns-through-cloud-dns"
    echoerr "-----------------------------------------------------------------------------"
    PS3="Have you completed the setup of Google Cloud DNS nameservers into your domain configuration or just press [ENTER] to choose the default (Yes) ? : "
    DNS_IS_SETUP=$(select_with_default "Yes" "No")
    DNS_IS_SETUP=${DNS_IS_SETUP:-Yes}
    if [ "$DNS_IS_SETUP" != "Yes" ]; then
        echo "Unable to continue without Google Cloud DNS being setup as Let's Encrypt requires it"
        exit 1
    fi
else
    echo "DNS base hostname appears to have nameserver setup so continuing on"
fi

setup_and_run_tf "static_ips"
setup_and_run_tf "spinnaker"
setup_and_run_tf "halyard"

echo "Quickstart complete"

cd "$CWD" || { echo "failed to return to $CWD" ; exit ; }
