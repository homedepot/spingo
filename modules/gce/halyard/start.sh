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
runuser -l root -c 'echo "${SCRIPT_SPINGO}" | base64 -d > /etc/profile.d/spingo.sh'

#CREATE USER
echo "Creating user"
useradd -s /bin/bash ${USER}
usermod -g google-sudoers ${USER}
mkhomedir_helper ${USER}

echo "Setting up repos"
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y --allow-unauthenticated --no-install-recommends kubectl python-pip jq google-cloud-sdk 

echo "Setting up directory permissions."
mkdir /${USER}
chown -R ${USER}:google-sudoers /${USER}
chmod -R 776 /${USER}

echo "Exporting values"
runuser -l ${USER} -c 'echo "export CLIENT_ID=${CLIENT_ID}" >> /home/${USER}/.bashrc'
runuser -l ${USER} -c 'echo "export CLIENT_SECRET=${CLIENT_SECRET}" >> /home/${USER}/.bashrc'
runuser -l ${USER} -c 'echo "export SPIN_UI_IP=${SPIN_UI_IP}" >> /home/${USER}/.bashrc'
runuser -l ${USER} -c 'echo "export SPIN_API_IP=${SPIN_API_IP}" >> /home/${USER}/.bashrc'
runuser -l ${USER} -c 'echo "echo \"CLIENT_ID, CLIENT_SECRET, SPIN_UI, SPIN_API_IP are loaded\" >>/home/${USER}/.bashrc'

echo "Downloading HAL"
cd /home/${USER}
runuser -l ${USER} -c 'curl -O https://raw.githubusercontent.com/spinnaker/halyard/master/install/debian/InstallHalyard.sh'
runuser -l ${USER} -c 'sudo bash InstallHalyard.sh -y --user ${USER}'


#this is hard coded because it is necessary name.
runuser -l ${USER} -c 'echo "${REPLACE}" | base64 -d > /home/${USER}/${USER}.json'

runuser -l ${USER} -c 'gcloud auth activate-service-account --key-file=/home/${USER}/${USER}.json'
runuser -l ${USER} -c 'gsutil rsync -d -r gs://${BUCKET} /${USER}'

echo "Setting symlinks"
runuser -l ${USER} -c 'rm -fdr /home/${USER}/.hal'
runuser -l ${USER} -c 'ln -s /${USER}/.hal /home/${USER}/'

echo "Setting up cluster access"
runuser -l ${USER} -c 'gcloud beta container clusters get-credentials ${USER}-${REGION} --region ${REGION} --project ${PROJECT}'

runuser -l ${USER} -c 'kubectl config set-credentials ${SPIN_CLUSTER_ACCOUNT} --token=$(kubectl get secret $(kubectl get secret --namespace=kube-system | grep default-token | awk '"'"'{print $1}'"'"') --namespace=kube-system -o jsonpath={.data.token} | base64 -d)'

runuser -l ${USER} -c 'kubectl config set-context $(kubectl config current-context) --user=${SPIN_CLUSTER_ACCOUNT}'
runuser -l ${USER} -c 'echo "${SCRIPT_SSL}" | base64 -d > /home/${USER}/setupSSL.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_SAML}" | base64 -d > /home/${USER}/setupSAML.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_HALYARD}" | base64 -d > /home/${USER}/setupHalyard.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_HALPUSH}" | base64 -d > /home/${USER}/halpush.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_HALGET}" | base64 -d > /home/${USER}/halget.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_HALDIFF}" | base64 -d > /home/${USER}/haldiff.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_K8SSL}" | base64 -d > /home/${USER}/setK8SSL.sh'
runuser -l ${USER} -c 'echo "${SCRIPT_RESETGCP}" | base64 -d > /home/${USER}/resetgcp.sh'

runuser -l ${USER} -c 'chmod +x /home/${USER}/halpush.sh'
runuser -l ${USER} -c 'chmod +x /home/${USER}/halget.sh'
runuser -l ${USER} -c 'chmod +x /home/${USER}/haldiff.sh'
runuser -l ${USER} -c 'chmod +x /home/${USER}/resetgcp.sh'
runuser -l ${USER}  -c 'echo "${SCRIPT_ALIASES}" | base64 -d > /home/${USER}/.bash_aliases'

#Use sudo -H -u spinnaker bash at log in or use spingo alias


