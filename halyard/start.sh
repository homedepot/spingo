#!/bin/bash
# This script is used in terraform VM setup to install halyard and necessary things.
# It creates a user named spinnaker and its home directory.
# It attempts to run everything as spinnaker as much as possible.

#################################
# DO THIS FOR ALL INSTALL SCRIPTS
# creates an install log.
#################################
set -x
logfile=/tmp/install.log
exec > $logfile 2>&1
#################################

echo "Setting up alias for sudo action."
runuser -l root -c 'echo "${PROFILE_ALIASES}" | base64 -d > /etc/profile.d/aliases.sh'

#CREATE USER
echo "Creating user"
useradd -s /bin/bash ${USER} -u 1978
usermod -g google-sudoers ${USER}
mkhomedir_helper ${USER}

echo "Setting up repos"
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
add-apt-repository -y ppa:rmescandon/yq
apt-get update
apt-get install -y --allow-unauthenticated --no-install-recommends kubectl python-pip jq google-cloud-sdk expect yq docker.io

echo "Setting up directory permissions."
mkdir /${USER}
chown -R ${USER}:google-sudoers /${USER}
chmod -R 776 /${USER}
usermod -aG docker ${USER}


echo "Downloading HAL"
cd /home/${USER}
runuser -l ${USER} -c 'curl -O https://raw.githubusercontent.com/spinnaker/halyard/master/install/debian/InstallHalyard.sh'
runuser -l ${USER} -c 'sudo bash InstallHalyard.sh -y --user ${USER}'


#this is hard coded because it is necessary name.
runuser -l ${USER} -c 'echo "${REPLACE}" | base64 -d > /home/${USER}/${USER}.json'

runuser -l ${USER} -c 'gcloud auth activate-service-account --key-file=/home/${USER}/${USER}.json'
runuser -l ${USER} -c 'gsutil rsync -x ".*\.kube/http-cache/|.*\.kube/cache/" -d -r gs://${BUCKET} /${USER}'

echo "Setting symlinks"
runuser -l ${USER} -c 'rm -fdr /home/${USER}/.hal'
runuser -l ${USER} -c 'ln -s /${USER}/.hal /home/${USER}/'
runuser -l ${USER} -c 'ln -s /${USER}/.kube /home/${USER}/'

echo "Setting up helper scripts"
runuser -l ${USER} -c 'echo "${SCRIPT_SSL}" | base64 -d > /home/${USER}/setupSSL.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_OAUTH}" | base64 -d > /home/${USER}/setupOAuth.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_HALYARD}" | base64 -d > /home/${USER}/setupHalyard.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_HALPUSH}" | base64 -d > /home/${USER}/halpush.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_HALGET}" | base64 -d > /home/${USER}/halget.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_HALDIFF}" | base64 -d > /home/${USER}/haldiff.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_SWITCH}" | base64 -d > /home/${USER}/halswitch.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_K8SSL}" | base64 -d > /home/${USER}/setupK8SSL.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_RESETGCP}" | base64 -d > /home/${USER}/resetgcp.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_MONITORING}" | base64 -d > /home/${USER}/setupMonitoring.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_SSL_KEYSTORE}" | base64 -d > /home/${USER}/setupCertbot.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_ONBOARDING}" | base64 -d > /home/${USER}/setupOnboarding.sh'

runuser -l ${USER} -c 'chmod +x /home/${USER}/*.sh'
runuser -l ${USER}  -c 'echo "${SCRIPT_ALIASES}" | base64 -d > /home/${USER}/.bash_aliases'
# Install micro editor because it's awesome
runuser -l ${USER}  -c 'cd /usr/local/bin; curl https://getmic.ro | sudo bash'
# format the json bindings file as this will probably be pulled intoa file later
runuser -l ${USER}  -c 'mkdir -p ~/.config/micro; echo "{\"Ctrl-y\": \"command:setlocal filetype yaml\"}" | jq -r "." - > ~/.config/micro/bindings.json'


echo "If you have not been exited to console yet just type ctrl-c to exit"
echo "startup complete"
#Use sudo -H -u spinnaker bash at log in or use spingo alias
