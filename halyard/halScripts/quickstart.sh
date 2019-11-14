#!/bin/bash

cd /home/${USER}

echo "Auto running setupCertbot.sh"
./setupCertbot.sh
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

echo "autostart complete please log into your Spinnaker deployment(s)"
