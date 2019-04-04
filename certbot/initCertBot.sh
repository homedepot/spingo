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
runuser -l root -c 'echo "alias showlog=\"tail -f /tmp/install.log\"" > /etc/profile.d/showlog.sh'
runuser -l root -c 'echo "alias pushcerts=\"gsutil rsync -d -r /${USER}/${USER} gs://${BUCKET}/${USER}\"" > /etc/profile.d/pushcerts.sh'
runuser -l root -c 'echo "alias pullcerts=\"gsutil rsync -d -r gs://${BUCKET}/${USER} /${USER}/${USER}\"" > /etc/profile.d/pullcerts.sh'


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

#install the plugin since ubuntu doesn't have it in repo
cd ~
mkdir source
cd source
git clone https://github.com/certbot/certbot.git
cd certbot/certbot-dns-google
pip install setuptools
python setup.py install

#write out test execution
echo "certbot certonly --test-cert --dns-google --config-dir /${USER}/${USER} --logs-dir ~/logs --work-dir ~/work --dns-google-credentials /home/${USER}/${USER}.json --dns-google-propagation-seconds 120 -d *.${DNS}." > /home/${USER}/execute-test.sh

#write out cert execution
echo "certbot certonly --dns-google --config-dir /${USER}/${USER} --logs-dir ~/logs --work-dir ~/work --dns-google-credentials /home/${USER}/${USER}.json --dns-google-propagation-seconds 120 -d *.${DNS}." > /home/${USER}/execute-only-if-you-are-sure.sh

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

runuser -l ${USER} -c 'gcloud auth activate-service-account --key-file=/home/${USER}/${USER}.json'
runuser -l ${USER} -c 'gsutil rsync -x ".*\.kube/http-cache/|.*\.kube/cache/" -d -r gs://${BUCKET}/${USER} /${USER}/${USER}'

# This is where the sym links will point and the google S3 bucket will be linked
chown -R ${USER}:google-sudoers /${USER}

# rsync does not persist the symlinks and certbot requires symlinks so we need to set them back
runuser -l ${USER} -c 'echo "${LINKER_SCRIPT}" | base64 -d > /home/${USER}/symlinker.sh'
runuser -l ${USER} -c 'echo "${MAKE_UPDATE_KEYSTORE_SCRIPT}" | base64 -d > /home/${USER}/make_or_update_keystore.sh'
runuser -l ${USER} -c 'chmod +x /home/${USER}/*.sh'
runuser -l ${USER} -c 'cd /home/${USER} && ./symlimker.sh'

echo "startup complete"
