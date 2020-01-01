#!/bin/bash

setup_and_run_tf(){
    DIR="$1"
    cd "$DIR" || { echo "cd to $DIR failed. Unable to run terraform commands. Cowardly exiting" ; return; }
    n=0
    until [ $n -ge 20 ]
    do
        ATTEMPT="try"
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
    terraform apply -auto-approve  || { echo "terraform apply of $DIR failed. Unable to run terraform commands. Cowardly exiting" ; exit 1; }
    cd ..
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
setup_and_run_tf "static_ips"
setup_and_run_tf "spinnaker"
setup_and_run_tf "halyard"

echo "Quickstart complete"
