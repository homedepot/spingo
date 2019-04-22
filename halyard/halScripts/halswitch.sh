#!/bin/bash

echo "-----------------------------------------------------------------------------"
CURR_DEPL=$(cat /spinnaker/.hal/config | yq r - 'currentDeployment')
echo "Current deployment is : $CURR_DEPL"
echo "-----------------------------------------------------------------------------"
PS3="Enter the number for the Spinnaker deployment to change to (ctrl-c to exit) : ";
select hal_name in $(cat /${USER}/.hal/config | yq r - deploymentConfigurations.*.name | sed -e 's/- //')
do
    if [ "$hal_name" == "" ]; then
        echo "You must select one of the currently configured deployments"
    elif [ "$CURR_DEPL" == "$hal_name" ]; then
        echo "No change needed to set current deployment to existing setting"
        break;
    else
        echo "-----------------------------------------------------------------------------"
        echo "New deployment $hal_name selected"
        hal config --set-current-deployment "$hal_name"
        break;
    fi
done
