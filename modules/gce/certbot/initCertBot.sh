#!/bin/bash
# This script is used in terraform VM setup to install certbot and necessary things.
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


useradd ${USER}
usermod -g google-sudoers ${USER}
mkhomedir_helper ${USER}

echo "Setting up alias for sudo action."
runuser -l root -c 'echo "alias spingo=\"sudo -H -u ${USER} bash\"" > /etc/profile.d/spingo.sh'

#Install Certbot
echo "deb http://packages.cloud.google.com/apt gcsfuse-bionic main" | tee /etc/apt/sources.list.d/gcsfuse.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
apt-get install software-properties-common
add-apt-repository universe
add-apt-repository ppa:certbot/certbot
apt-get update
apt-get install -y --allow-unauthenticated --no-install-recommends google-cloud-sdk gcsfuse
apt-get install -y --allow-unauthenticated --no-install-recommends python-certbot-apache
apt-get install -y --allow-unauthenticated --no-install-recommends python-pip

#install the plugin since ubuntu doesn't have it in repo
cd ~
mkdir source
cd source
git clone https://github.com/certbot/certbot.git
cd certbot/certbot-dns-google
pip install setuptools
python setup.py install


#write out test execution
echo "certbot certonly --test-cert --dns-google --config-dir /certbot/certbot --logs-dir ~/logs --work-dir ~/work --dns-google-credentials /home/certbot/certbot.json --dns-google-propagation-seconds 120 -d np-platforms-cd-thd.gcp.homedepot.com." > /home/${USER}/execute-test.sh

runuser -l ${USER} -c 'mkdir /home/${USER}/logs'
runuser -l ${USER} -c 'mkdir /home/${USER}/work'


echo "copy json file"
#Notice this is available in the start script.  Not sure if this is safer than the bucket.
echo "${REPLACE}" > /home/${USER}/${USER}.json

chown -R ${USER}:google-sudoers /home/${USER}
chmod -R 776 /home/${USER}

#This is where the sym links will point and the google S3 bucket will be linked
mkdir /${USER}
chown -R ${USER}:google-sudoers /${USER}
chmod -R 776 /${USER}

#Mount the drive as /${USER}
runuser -l ${USER} -c 'gcsfuse --dir-mode 777 ${BUCKET} /${USER}'


#This will set the spinnaker user as default gcloud user.
#Note the secret file must exist in the bucket.
#If we change to a key management tool this should be moved to a local directory and pulled from vault or keystore here.
runuser -l ${USER} -c 'gcloud auth activate-service-account --key-file=/home/${USER}/${USER}.json'
runuser -l ${USER} -c 'touch /home/${USER}/complete.done'
