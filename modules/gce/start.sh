#!/bin/bash

<<SCRIPT
useradd spinnaker
usermod -g google-sudoers spinnaker
mkhomedir_helper spinnaker

echo "deb http://packages.cloud.google.com/apt gcsfuse-xenial main" | tee /etc/apt/sources.list.d/gcsfuse.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y --allow-unauthenticated --no-install-recommends google-cloud-sdk gcsfuse
apt-get install -y kubectl


mkdir /spinnaker
chown -R spinnaker:google-sudoers /spinnaker
chmod -R 776 /spinnaker

runuser -l spinnaker -c 'gcsfuse --dir-mode 777  np-platforms-cd-thd-halyard-bucket /spinnaker'

runuser -l spinnaker -c 'ln -s /spinnaker/.kube /home/spinnaker/.kube'
runuser -l spinnaker -c 'ln -s /spinnaker/.gcp /home/spinnaker/.gcp'

cd /home/spinnaker
runuser -l spinnaker -c 'curl -O https://raw.githubusercontent.com/spinnaker/halyard/master/install/debian/InstallHalyard.sh'
runuser -l spinnaker -c 'sudo bash InstallHalyard.sh -y --user spinnaker'
runuser -l spinnaker -c 'rm -rfd /home/spinnaker/.hal'
runuser -l spinnaker -c 'ln -s /spinnaker/.hal /home/spinnaker/.hal'

SCRIPT
#Use sudo -H -u spinnaker bash to log in



