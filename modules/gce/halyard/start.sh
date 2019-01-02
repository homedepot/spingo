#!/bin/bash
# This script is used in terraform VM setup to install halyard and necessary things.
# It creates a user named spinnaker and its home directory.
# It attempts to run everything as spinnaker as much as possible.

useradd ${USER}
usermod -g google-sudoers ${USER}
mkhomedir_helper ${USER}

echo "deb http://packages.cloud.google.com/apt gcsfuse-xenial main" | tee /etc/apt/sources.list.d/gcsfuse.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y --allow-unauthenticated --no-install-recommends google-cloud-sdk gcsfuse
apt-get install -y kubectl

#This is where the sym links will point and the google S3 bucket will be linked
mkdir /${USER}
chown -R ${USER}:google-sudoers /${USER}
chmod -R 776 /${USER}

echo "alias spingo='sudo -H -u spinnaker bash'" > /tmp/spingo.sh
cp /tmp/spingo.sh /etc/profile.d

#Mount the drive as /spinnaker
runuser -l ${USER} -c 'gcsfuse --dir-mode 777  ${BUCKET} /${USER}'
runuser -l ${USER} -c 'touch /${USER}/good.txt'
# give it a retry
if ! ls /${USER}/good.txt 1> /dev/null 2>&1; then
  touch /tmp/directory_worked.chk
else
  runuser -l ${USER} -c 'gcsfuse --dir-mode 777  ${BUCKET} /${USER}'
fi


runuser -l ${USER} -c 'ln -s /${USER}/.kube /home/${USER}/.kube'
runuser -l ${USER} -c 'ln -s /${USER}/.gcp /home/${USER}/.gcp'

runuser -l ${USER} -c 'echo "export CLIENT_ID=${CLIENT_ID}" >> /home/${USER}/.bashrc'
runuser -l ${USER} -c 'echo "export CLIENT_SECRET=${CLIENT_SECRET}" >> /home/${USER}/.bashrc'
runuser -l ${USER} -c 'echo "export SPIN_UI_IP=${SPIN_UI_IP}" >> /home/${USER}/.bashrc'
runuser -l ${USER} -c 'echo "export SPIN_API_IP=${SPIN_API_IP}" >> /home/${USER}/.bashrc'
runuser -l ${USER} -c 'echo "echo \"CLIENT_ID, CLIENT_SECRET, SPIN_UI, SPIN_API_IP are loaded\" >>/home/${USER}/.bashrc'

cd /home/${USER}
runuser -l ${USER} -c 'curl -O https://raw.githubusercontent.com/${USER}/halyard/master/install/debian/InstallHalyard.sh'
runuser -l ${USER} -c 'sudo bash InstallHalyard.sh -y --user ${USER}'
runuser -l ${USER} -c 'rm -rfd /home/${USER}/.hal'
runuser -l ${USER} -c 'ln -s /${USER}/.hal /home/${USER}/.hal'

#This will set the spinnaker user as default gcloud user.
#Note the secret file must exist in the bucket.
#If we change to a key management tool this should be moved to a local directory and pulled from vault or keystore here.
#Note halinit.sh depends on this existing.
runuser -l ${USER} -c 'gcloud auth activate-service-account --key-file=/home/${USER}/.gcp/${USER}.json'
runuser -l ${USER} -c 'gcloud beta container clusters get-credentials ${USER}-${REGION} --region ${REGION} --project ${PROJECT}'

runuser -l root -c 'echo "alias spingo=\"sudo -H -u spinnaker bash\"" > /etc/profile.d/spingo.sh'


#Use sudo -H -u spinnaker bash at log in



