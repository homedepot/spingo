#!/bin/bash

# cwd=$(pwd)
# cd /certbot/certbot/live/${DNS}

CERBOT_PATH="/${USER}/certbot/"
CERTSTORE_PATH="/${USER}/certstore/certificates/"

docker run \
  -e GCE_PROJECT="${PROJECT}" \
  -e GCE_SERVICE_ACCOUNT_FILE="/gcloud-service-account.json" \
  -v /${USER}/.gcp/certbot.json:/gcloud-service-account.json:ro \
  -v /${USER}/certstore:/certstore \
  -u 1001:1001 \
    goacme/lego \
      --path="/certstore" \
      --accept-tos \
      --dns=gcloud \
      --pem \
      --email="jeffrey_k_billimek@demo.homedepot.com" \
      --domains="*.demo3.spinnaker.homedepot.com" \
      run

openssl pkcs12 -export -out wildcard.pkcs12 -in wildcard.pem -name spinnaker -password pass:"${KEYSTORE_PASS}"
keytool -v -importkeystore -srckeystore wildcard.pkcs12 -destkeystore wildcard.jks -deststoretype JKS -storepass "${KEYSTORE_PASS}" -srcstorepass "${KEYSTORE_PASS}" -noprompt
keytool -trustcacerts -keystore wildcard.jks -importcert -file chain.pem -storepass "${KEYSTORE_PASS}" # this will fail if certificate renewal instead of new cert but that is ok
cp privkey.pem wildcard.key
cp fullchain.pem wildcard.crt
cp wildcard.key ../../${DNS}_wildcard.key
cp wildcard.crt ../../${DNS}_wildcard.crt
cp wildcard.jks ../../${DNS}_wildcard.jks
# cd "$cwd"
echo "setup complete"


#!/bin/bash

#cwd=$(pwd)
#cd /certbot/certbot/live/ ${DNS}

#cat fullchain.pem privkey.pem > wildcard.pem
openssl pkcs12 -export -out /spinnaker/certstore/certificates/wildcard.pkcs12 -in /spinnaker/certstore/certificates/_. ${DNS}.pem -name spinnaker -password pass:"nosecrets"
keytool -v -importkeystore -srckeystore /spinnaker/certstore/certificates/wildcard.pkcs12 -destkeystore /spinnaker/certstore/certificates/wildcard.jks -deststoretype JKS -storepass "nosecrets" -srcstorepass "nosecrets" -noprompt
#keytool -trustcacerts -keystore wildcard.jks -importcert -file chain.pem -storepass "nosecrets" # this will fail if certificate renewal instead of new cert but that is ok
keytool -trustcacerts -keystore /spinnaker/certstore/certificates/wildcard.jks -importcert -file /spinnaker/certstore/certificates/_. ${DNS}.crt -storepass "nosecrets" -alias # this will fail if certificate renewal instead of new cert but that is ok
#cp privkey.pem wildcard.key
#cp fullchain.pem wildcard.crt
cp /spinnaker/certstore/certificates/_. ${DNS}.key /spinnaker/certbot/ ${DNS}_wildcard.key
cp /spinnaker/certstore/certificates/_. ${DNS}.crt /spinnaker/certbot/ ${DNS}_wildcard.crt
cp /spinnaker/certstore/certificates/wildcard.jks /spinnaker/certbot/ ${DNS}_wildcard.jks
#cd "$cwd"
echo "setup complete"