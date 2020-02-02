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

echo "Adding prompt including google project to .bashrc skeleton file"
runuser -l root -c 'echo "\[\e]0;\u@\h: \w\a\]\[\033[01;32m\]\u@${GOOGLE_PROJECT}\[\033[00m\]\[\033[01;34m\]:\w\[\033[00m\]$" >> /etc/skel/.bashrc"'

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
apt-get install -y --allow-unauthenticated --no-install-recommends kubectl python-pip jq google-cloud-sdk expect yq docker.io unzip

echo "Setting up directory permissions."
mkdir /${USER}
chown -R ${USER}:google-sudoers /${USER}
chmod -R 776 /${USER}
usermod -aG docker ${USER}


echo "Downloading HAL"
cd /home/${USER}
runuser -l ${USER} -c 'curl -O https://raw.githubusercontent.com/spinnaker/halyard/master/install/debian/InstallHalyard.sh'
runuser -l ${USER} -c 'sudo bash InstallHalyard.sh -y --user ${USER}'

echo "Installing Vault"
runuser -l ${USER} -c 'curl "https://releases.hashicorp.com/vault/1.2.3/vault_1.2.3_linux_amd64.zip" > /home/${USER}/vault.zip'
runuser -l ${USER} -c 'unzip /home/${USER}/vault.zip -d /home/${USER}'
runuser -l ${USER} -c 'sudo mv /home/${USER}/vault /usr/local/bin/vault'
runuser -l ${USER} -c 'rm /home/${USER}/vault.zip'

echo "Installing Helm"
runuser -l ${USER} -c 'curl -LO https://git.io/get_helm.sh'
runuser -l ${USER} -c 'chmod 700 /home/${USER}/get_helm.sh'
runuser -l ${USER} -c './get_helm.sh'

#this is hard coded because it is necessary name.
runuser -l ${USER} -c 'echo "${REPLACE}" | base64 -d > /home/${USER}/${USER}.json'

runuser -l ${USER} -c 'gcloud auth activate-service-account --key-file=/home/${USER}/${USER}.json'
runuser -l ${USER} -c 'gsutil -m rsync -x ".*\.kube/http-cache/|.*\.kube/cache/|.*\.kube/config" -d -r gs://${BUCKET} /${USER}'
runuser -l ${USER} -c 'curl -LO https://storage.googleapis.com/spinnaker-artifacts/spin/$(curl -s https://storage.googleapis.com/spinnaker-artifacts/spin/latest)/linux/amd64/spin'
runuser -l ${USER} -c 'chmod +x spin'
runuser -l ${USER} -c 'sudo mv spin /usr/local/bin/spin'

echo "Setting symlinks"
runuser -l ${USER} -c 'rm -fdr /home/${USER}/.hal'
runuser -l ${USER} -c 'ln -s /${USER}/.hal /home/${USER}/'
runuser -l ${USER} -c 'ln -s /${USER}/.kube /home/${USER}/'
runuser -l ${USER} -c 'ln -s /${USER}/.spin /home/${USER}/'

echo "Setting up helper scripts"
runuser -l ${USER} -c 'echo "${SCRIPT_SSL}" | base64 -d > /home/${USER}/setupSSL.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_OAUTH}" | base64 -d > /home/${USER}/setupOAuth.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_HALYARD}" | base64 -d > /home/${USER}/setupHalyard.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_KUBERNETES}" | base64 -d > /home/${USER}/setupKubernetes.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_HALPUSH}" | base64 -d > /home/${USER}/halpush.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_HALGET}" | base64 -d > /home/${USER}/halget.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_HALDIFF}" | base64 -d > /home/${USER}/haldiff.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_SWITCH}" | base64 -d > /home/${USER}/halswitch.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_K8SSL}" | base64 -d > /home/${USER}/setupK8SSL.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_RESETGCP}" | base64 -d > /home/${USER}/resetgcp.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_MONITORING}" | base64 -d > /home/${USER}/setupMonitoring.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_SSL_KEYSTORE}" | base64 -d > /home/${USER}/setupCertbot.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_ONBOARDING}" | base64 -d > /home/${USER}/setupOnboarding.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_SLACK}" | base64 -d > /home/${USER}/setupSlack.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_X509}" | base64 -d > /home/${USER}/createX509.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_QUICKSTART}" | base64 -d > /home/${USER}/quickstart.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_COMMON}" | base64 -d > /home/${USER}/commonFunctions.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_CREATE_FIAT}" | base64 -d > /home/${USER}/createFiatServiceAccount.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_CURRENT_DEPLOYMENT}" | base64 -d > /home/${USER}/configureToCurrentDeployment.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_ONBOARDING_PIPELINE}" | base64 -d > /home/${USER}/onboardingNotificationsPipeline.json'
runuser -l ${USER} -c 'echo "${SCRIPT_SPINGO_ADMIN_APP}" | base64 -d > /home/${USER}/spingoAdminApplication.json'
runuser -l ${USER} -c 'echo "${SCRIPT_VAULT}" | base64 -d > /home/${USER}/setupVault.sh'

runuser -l ${USER} -c 'chmod +x /home/${USER}/*.sh'
runuser -l ${USER}  -c 'echo "${SCRIPT_ALIASES}" | base64 -d > /home/${USER}/.bash_aliases'
# Install micro editor because it's awesome
runuser -l ${USER}  -c 'cd /usr/local/bin; curl https://getmic.ro | sudo bash'
# format the json bindings file as this will probably be pulled intoa file later
runuser -l ${USER}  -c 'mkdir -p ~/.config/micro; echo "{\"Ctrl-y\": \"command:setlocal filetype yaml\"}" | jq -r "." - > ~/.config/micro/bindings.json'

runuser -l ${USER} -c 'if [ ${AUTO_START_HALYARD_QUICKSTART} == true ] && [ ! -d /${USER}/.hal ]; then time /home/${USER}/quickstart.sh; fi'
runuser -l ${USER} -c 'if [ -d /${USER}/.hal ]; then source /home/${USER}/configureToCurrentDeployment.sh;  fi'

#extract userscripts
runuser -l ${USER} -c 'echo "${USER_SCRIPTS}" | base64 -d | tar -xf - -C /home/${USER}'


echo "If you have not been exited to console yet just type ctrl-c to exit"
echo "startup complete"
#Use sudo -H -u spinnaker bash at log in or use spingo alias
