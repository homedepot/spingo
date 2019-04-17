#!/bin/bash

export PASS=""


export KEYSTORE="saml-$1.jks"
export ALIAS="spinnaker.$1"
export CA="*.spinnaker.homedepot.com"
CERTIFICATE="saml-$1.cer"
PROJECT="np-platforms-cd-thd"
CERT_BUCKET_PATH="gs://${PROJECT}-halyard-bucket/saml"

if [[ -z $1 ]]; then
    echo "You must pass-in an argument (e.g. 'np') to continue"
    exit 1
elif [[ -z $PASS ]]; then
    echo "PASS must be set to continue"
    exit 1
else
  ./saml-script.exp && \
  keytool -export -rfc -alias "$ALIAS" -file "$CERTIFICATE" -keystore "$KEYSTORE" -storepass "$PASS" && \
  echo "copying certificate files to $CERT_BUCKET_PATH"; \
  gsutil cp "$KEYSTORE" "$CERT_BUCKET_PATH"; \
  gsutil cp "$CERTIFICATE" "$CERT_BUCKET_PATH"
fi

unset KEYSTORE ALIAS PASS CA
