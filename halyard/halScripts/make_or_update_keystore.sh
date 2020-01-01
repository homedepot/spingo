#!/bin/bash

CERBOT_PATH="/${USER}/certbot"
CERTSTORE_PATH="/${USER}/certstore/certificates"

if [ -f "$CERTSTORE_PATH/_.${DNS}.json" ];then
    echo "===== OPERATION: RENEW ====="
    LEGO_CMD="renew --days 45 "
else
    echo "===== OPERATION: INITIAL REQUEST ====="
    LEGO_CMD="run"
fi

mkdir -p "$CERTSTORE_PATH"
mkdir -p "$CERBOT_PATH"

n=0
until [ $n -ge 5 ]
do
   docker run \
  -e GCE_PROJECT="${PROJECT}" \
  -e GCE_SERVICE_ACCOUNT_FILE="/gcloud-service-account.json" \
  -v /${USER}/.gcp/certbot.json:/gcloud-service-account.json:ro \
  -v /${USER}/certstore:/certstore \
  -u 1978:1978 \
    goacme/lego \
      --path="/certstore" \
      --accept-tos \
      --dns=gcloud \
      --pem \
      --email="${CERTBOT_EMAIL}" \
      --domains="*.${DNS}" \
      --domains="${DNS}" \
      $LEGO_CMD && break
   n=$((n+1))
   sleep 3
done

if [ ! -f "$CERTSTORE_PATH/_.${DNS}.json" ];then
  echo "Unable to find certificate files"
  exit 1
fi

openssl pkcs12 -export -out "$CERTSTORE_PATH"/wildcard.pkcs12 -in "$CERTSTORE_PATH"/_.${DNS}.pem -name spinnaker -password pass:"${KEYSTORE_PASS}"
keytool -v -importkeystore -srckeystore "$CERTSTORE_PATH"/wildcard.pkcs12 -destkeystore "$CERTSTORE_PATH"/wildcard.jks -deststoretype JKS -storepass "${KEYSTORE_PASS}" -srcstorepass "${KEYSTORE_PASS}" -noprompt
keytool -trustcacerts -keystore "$CERTSTORE_PATH"/wildcard.jks -importcert -file "$CERTSTORE_PATH"/_.${DNS}.crt -storepass "${KEYSTORE_PASS}" -noprompt # this will fail if certificate renewal instead of new cert but that is ok

cp "$CERTSTORE_PATH"/_.${DNS}.key "$CERBOT_PATH"/${DNS}_wildcard.key
cp "$CERTSTORE_PATH"/_.${DNS}.crt "$CERBOT_PATH"/${DNS}_wildcard.crt
cp "$CERTSTORE_PATH"/wildcard.jks "$CERBOT_PATH"/${DNS}_wildcard.jks

echo "setup complete"
