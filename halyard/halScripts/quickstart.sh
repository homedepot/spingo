#!/bin/bash

die() { echo "$*" 1>&2 ; exit 1; }

cd /home/${USER}

echo "Auto running setupKubernetes.sh"
./setupKubernetes.sh

if [ "$?" -ne 0 ]; then
    die "Unable to setup Kubernetes so no point in continuing"
fi

echo "Auto running setupCertbot.sh"
./setupCertbot.sh
echo "Auto running setupVault.sh"
./setupVault.sh
echo "Auto running setupHalyard.sh"
./setupHalyard.sh
echo "Auto running setupSSL.sh"
./setupSSL.sh
echo "Auto running setupOAuth.sh"
./setupOAuth.sh
echo "Auto running setupSlack.sh"
./setupSlack.sh
echo "Auto running setupOnboarding.sh"
./setupOnboarding.sh
echo "Auto running setupMonitoring.sh"
./setupMonitoring.sh

echo "Auto running halpush to save configuration to halyard bucket"
./halpush.sh

echo "Autostart complete please log into your Spinnaker deployment(s)"
