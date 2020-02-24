#!/bin/bash

. /home/${USER}/commonFunctions.sh

CURR_DEPLOYMENT="$(cat /${USER}/.hal/config | yq r - 'currentDeployment')"
update_spin "$CURR_DEPLOYMENT"
update_kube "$CURR_DEPLOYMENT"
