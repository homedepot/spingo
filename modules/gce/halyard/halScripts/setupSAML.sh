#!/bin/bash

#This is the keytool command used to create the .jks
# keytool -genkey -v -keystore saml.jks -alias spinnaker.np -keyalg RSA -keysize 2048 -storepass nosecrets -validity 10000
#Avoid losing the keystore because security has to change stuff if this is changed.

#To pull out the cert you have to import it to a pkcs12 file note use .p12 if windows
#keytool -importkeystore -srckeystore saml.jks -destkeystore saml.jks -deststoretype pkcs12
#You can extract the cert from the .p12
#openssl pkcs12 -in PKCS12file -out keys_out.txt 
#Then convert to cert.


KEYSTORE_PATH="/${USER}/saml/saml.jks"
KEYSTORE_PASSWORD="nosecrets"
METADATA_PATH="/${USER}/saml/ssosecure-qaMetadata.xml"
#SERVICE_ADDR_URL="https://spinnaker-api.np-platforms-cd-thd.gcp.homedepot.com"
SERVICE_ADDR_URL="${API_URL}"
ISSUER_ID="spinnaker.np"

 hal config security authn saml edit \
   --keystore $KEYSTORE_PATH \
   --keystore-alias $ISSUER_ID \
   --keystore-password $KEYSTORE_PASSWORD \
   --metadata $METADATA_PATH \
   --issuer-id $ISSUER_ID \
   --service-address-url $SERVICE_ADDR_URL \
      
 hal config security authn saml enable
    
echo "You will need to do a hal deploy apply to push the changes."

