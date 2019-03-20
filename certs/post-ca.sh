#!/bin/bash

PROJECT="np-platforms-cd-thd"

SIGNED_WILDCARD_CERTIFICATE="spinnaker.homedepot.com.cer"
WILDCARD_CERT_PRIVATE_KEY="wildcard.key"
WILDCARD_KEYSTORE="wildcard.jks"
CERT_BUCKET_PATH="gs://${PROJECT}-halyard-bucket/certs"

# TODO: enter the appripriate values here
WILDCARD_KEY_PASSWORD=""
JKS_PASSWORD=""

if [[ -z $JKS_PASSWORD ]] || [[ -z $WILDCARD_KEY_PASSWORD ]]; then
    echo "both WILDCARD_KEY_PASSWORD and JKS_PASSWORD must be set to continue"
    exit 1
else
    echo "generating PKCS12 file"
    openssl pkcs12 -export -clcerts \
    -in ${SIGNED_WILDCARD_CERTIFICATE} \
    -inkey ${WILDCARD_CERT_PRIVATE_KEY} \
    -out wildcard.p12 \
    -name wilcard \
    -passin pass:${WILDCARD_KEY_PASSWORD} \
    -password pass:${WILDCARD_KEY_PASSWORD}

    echo "generating the keystore"
    keytool \
    -importkeystore \
    -srckeystore wildcard.p12 \
    -srcstoretype pkcs12 \
    -srcalias wildcard \
    -destkeystore ${WILDCARD_KEYSTORE} \
    -destalias wildcard \
    -deststoretype pkcs12 \
    -deststorepass ${JKS_PASSWORD} \
    -destkeypass ${JKS_PASSWORD} \
    -srcstorepass ${WILDCARD_KEY_PASSWORD}

    keytool \
    -importcert \
    -keystore ${WILDCARD_KEYSTORE} \
    -alias ca \
    -file ${SIGNED_WILDCARD_CERTIFICATE} \
    -storepass ${JKS_PASSWORD} \
    -noprompt

    echo "copying certificate files to $CERT_BUCKET_PATH"
    gsutil cp ${SIGNED_WILDCARD_CERTIFICATE} ${CERT_BUCKET_PATH}
    gsutil cp ${WILDCARD_CERT_PRIVATE_KEY} ${CERT_BUCKET_PATH}
    gsutil cp ${WILDCARD_KEYSTORE} ${CERT_BUCKET_PATH}
fi

