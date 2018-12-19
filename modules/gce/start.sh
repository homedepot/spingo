#!/bin/bash
# This script is used in terraform VM setup to install halyard and necessary things.
# It creates a user named spinnaker and its home directory.
# It attempts to run everything as spinnaker as much as possible.
#<<SCRIPT
useradd spinnaker
usermod -g google-sudoers spinnaker
mkhomedir_helper spinnaker

echo "deb http://packages.cloud.google.com/apt gcsfuse-xenial main" | tee /etc/apt/sources.list.d/gcsfuse.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y --allow-unauthenticated --no-install-recommends google-cloud-sdk gcsfuse
apt-get install -y kubectl

#This is where the sym links will point and the google S3 bucket will be linked
mkdir /spinnaker
chown -R spinnaker:google-sudoers /spinnaker
chmod -R 776 /spinnaker

#Mount the drive as /spinnaker
runuser -l spinnaker -c 'gcsfuse --dir-mode 777  np-platforms-cd-thd-halyard-bucket /spinnaker'

runuser -l spinnaker -c 'ln -s /spinnaker/.kube /home/spinnaker/.kube'
runuser -l spinnaker -c 'ln -s /spinnaker/.gcp /home/spinnaker/.gcp'

cd /home/spinnaker
runuser -l spinnaker -c 'curl -O https://raw.githubusercontent.com/spinnaker/halyard/master/install/debian/InstallHalyard.sh'
runuser -l spinnaker -c 'sudo bash InstallHalyard.sh -y --user spinnaker'
runuser -l spinnaker -c 'rm -rfd /home/spinnaker/.hal'
runuser -l spinnaker -c 'ln -s /spinnaker/.hal /home/spinnaker/.hal'

#This will set the spinnaker user as default gcloud user.
#Note the secret file must exist in the bucket.
#If we change to a key management tool this should be moved to a local directory and pulled from vault or keystore here.
#Note halinit.sh depends on this existing.
runuser -l spinnaker -c 'gcloud auth activate-service-account --key-file=/home/spinnaker/.gcp/spinnaker.json'
runuser -l spinnaker -c 'gcloud beta container clusters get-credentials spinnaker-us-east1 --region us-east1 --project np-platforms-cd-thd'
#SCRIPT
#Use sudo -H -u spinnaker bash at log in



