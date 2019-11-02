#!/bin/bash

update_spin(){
    if [ -d /${USER}/x509 ]; then
        if [ -L /home/${USER}/.spin/config ]; then
            unlink /home/${USER}/.spin/config
        fi
        ln -s /home/${USER}/.spin/"$1".config /home/${USER}/.spin/config
    fi
}

PROJECT_NAME="${PROJECT_NAME}"
ACCOUNT="${ONBOARDING_ACCOUNT}"
JSON_SA_KEY="${PATH_TO_ONBOARDING_KEY}"
SPIN_SUB_NAME="${ONBOARDING_SUBSCRIPTION}"
GCP_SUB_NAME="${ONBOARDING_SUBSCRIPTION}"
export COMMA_SEPERATED_GROUPS="gg_spinnaker_admins"
export CERT_NAME="spingoadmin"

if [ ! -d /${USER}/x509 ]; then
  mkdir /${USER}/x509
fi

${HALYARD_COMMANDS}

/home/${USER}/createX509.sh

update_spin "$(cat /${USER}/.hal/config | yq r - 'currentDeployment')"

echo "Onboarding Automation configured and ready"
