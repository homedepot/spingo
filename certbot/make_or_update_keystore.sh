#!/bin/bash

cwd=$(pwd)
cd /certbot/certbot/live/${DNS}

cat fullchain.pem privkey.pem > wildcard.pem
openssl pkcs12 -export -out wildcard.pkcs12 -in wildcard.pem -name spinnaker -password pass:${KEYSTORE_PASS}
keytool -v -importkeystore -srckeystore wildcard.pkcs12 -destkeystore wildcard.jks -deststoretype JKS -storepass ${KEYSTORE_PASS} -srcstorepass ${KEYSTORE_PASS} -noprompt
keytool -trustcacerts -keystore wildcard.jks -importcert -file chain.pem # this will fail if certificate renewal instead of new cert but that is ok
cp privkey.pem wildcard.key
cp fullchain.pem wildcard.crt
cp wildcard.key ../../${DNS}_wildcard.key
cp wildcard.crt ../../${DNS}_wildcard.crt
cp wildcard.jks ../../${DNS}_wildcard.jks
cd "$cwd"
