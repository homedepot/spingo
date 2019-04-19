#!/bin/bash

echo "-----------------------------------------------------------------------------"
PS3="Enter the number for the Spinnaker deployment to change to (ctrl-c to exit) : ";
select hal_name in $(cat /${USER}/.hal/config | yq r - deploymentConfigurations.*.name | sed -e 's/- //')
do
    if [ "$hal_name" == "" ]; then
        echo "You must select one of the currently configured deployments"
    else
        echo "-----------------------------------------------------------------------------"
        echo "$hal_name selected"
        hal config --set-current-deployment "$hal_name"
        break;
    fi
done
