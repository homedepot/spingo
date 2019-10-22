#!/bin/bash

if [ -f "/certstore/certificates/_.${DNS}.json" ] 
then
    echo "===== OPERATION: RENEW ====="
    LEGO_CMD="renew --days 45 "
else
    echo "===== OPERATION: INITIAL REQUEST ====="
    LEGO_CMD="run"
fi

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
      --email="${CERTBOT_EMAIL}" \
      --domains="*.${DNS}" \
      $LEGO_CMD

openssl pkcs12 -export -out "$CERTSTORE_PATH"/wildcard.pkcs12 -in "$CERTSTORE_PATH"/_. ${DNS}.pem -name spinnaker -password pass:"nosecrets"
keytool -v -importkeystore -srckeystore "$CERTSTORE_PATH"/wildcard.pkcs12 -destkeystore "$CERTSTORE_PATH"/wildcard.jks -deststoretype JKS -storepass "nosecrets" -srcstorepass "nosecrets" -noprompt
keytool -trustcacerts -keystore "$CERTSTORE_PATH"/wildcard.jks -importcert -file "$CERTSTORE_PATH"/_. ${DNS}.crt -storepass "nosecrets" -noprompt # this will fail if certificate renewal instead of new cert but that is ok

cp "$CERTSTORE_PATH"/_.${DNS}.key "$CERBOT_PATH"/${DNS}_wildcard.key
cp "$CERTSTORE_PATH"/_.${DNS}.crt "$CERBOT_PATH"/${DNS}_wildcard.crt
cp "$CERTSTORE_PATH"/wildcard.jks "$CERBOT_PATH"/${DNS}_wildcard.jks

echo "setup complete"
