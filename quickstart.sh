#!/bin/bash

setup_and_run_tf(){
    DIR="$1"
    cd "$DIR"
    terraform init
    terraform apply -auto-approve
    cd ..
}

./scripts/initial_setup.sh

if [ "$?" -ne 0 ];then
    echo "Initial setup failed so cowardly exiting"
    exit 1
fi

setup_and_run_tf "dns"
setup_and_run_tf "static_ips"
setup_and_run_tf "spinnaker"
setup_and_run_tf "halyard"
