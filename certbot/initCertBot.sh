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
# local gcp user aliases
runuser -l root -c 'echo "${PROFILE_ALIASES}" | base64 -d  > /etc/profile.d/aliases.sh'
# certbot user aliases
runuser -l root -c 'echo "${USER_ALIASES}" | base64 -d  > /home/${USER}/.bash_aliases'


#Install Certbot
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
apt-get install software-properties-common
add-apt-repository universe
add-apt-repository ppa:certbot/certbot
apt-get update
apt-get install -y --allow-unauthenticated --no-install-recommends google-cloud-sdk
apt-get install -y --allow-unauthenticated --no-install-recommends python-certbot-apache
apt-get install -y --allow-unauthenticated --no-install-recommends python-pip
apt-get install -y --allow-unauthenticated --no-install-recommends openjdk-11-jre-headless # need this for keytool
pip install setuptools
pip install certbot-dns-google

#write out test execution
echo "certbot certonly --test-cert --dns-google --config-dir /${USER}/${USER} --logs-dir ~/logs --work-dir ~/work --dns-google-propagation-seconds 120 -d *.${DNS}" > /home/${USER}/execute-test.sh

#write out cert execution
echo "certbot certonly --dns-google --config-dir /${USER}/${USER} --logs-dir ~/logs --work-dir ~/work --dns-google-propagation-seconds 120 -d *.${DNS}" > /home/${USER}/execute-only-if-you-are-sure.sh

#write out test renew
echo "certbot renew --dry-run --config-dir /${USER}/${USER} --logs-dir ~/logs --work-dir ~/work" > /home/${USER}/execute-renew-test.sh

#write out renew
echo "certbot renew --config-dir /${USER}/${USER} --logs-dir ~/logs --work-dir ~/work" > /home/${USER}/execute-renew.sh

runuser -l ${USER} -c 'mkdir /home/${USER}/logs'
runuser -l ${USER} -c 'mkdir /home/${USER}/work'

echo "copy json file"
#Notice this is available in the start script.  Not sure if this is safer than the bucket.
echo "${REPLACE}" > /home/${USER}/${USER}.json

chown -R ${USER}:google-sudoers /home/${USER}
chmod -R 776 /home/${USER}

mkdir -p /${USER}/${USER}
chown -R ${USER}:google-sudoers /${USER}
chmod -R 776 /${USER}

runuser -l ${USER} -c 'gsutil rsync -x ".*\.kube/http-cache/|.*\.kube/cache/" -d -r gs://${BUCKET}/${USER} /${USER}/${USER}'

# This is where the sym links will point and the google S3 bucket will be linked
chown -R ${USER}:google-sudoers /${USER}

# rsync does not persist the symlinks and certbot requires symlinks so we need to set them back
runuser -l ${USER} -c 'echo "${LINKER_SCRIPT}" | base64 -d > /home/${USER}/symlinker.sh'
runuser -l ${USER} -c 'echo "${MAKE_UPDATE_KEYSTORE_SCRIPT}" | base64 -d > /home/${USER}/make_or_update_keystore.sh'
runuser -l ${USER} -c 'chmod +x /home/${USER}/*.sh'
runuser -l ${USER} -c 'cd /home/${USER} && ./symlinker.sh'

echo "If you have not been exited to console yet just type ctrl-c to exit"
echo "startup complete"
