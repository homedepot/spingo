#!/bin/bash

setup_and_run_tf(){
    DIR="$1"
    cd "$DIR" || { echo "cd to $DIR failed. Unable to run terraform commands. Cowardly exiting" ; return; }
    terraform init
    terraform apply -auto-approve
    cd ..
}

if ! ./scripts/initial_setup.sh
then
    echo "Initial setup failed so cowardly exiting"
    exit 1
fi

setup_and_run_tf "dns"
setup_and_run_tf "static_ips"
setup_and_run_tf "spinnaker"
setup_and_run_tf "halyard"

echo "Quickstart complete"
