#!/bin/bash

./home/${USER}/setupK8SSL.sh

hal config security ui edit \
    --override-base-url ${UI_URL}

hal config security api edit \
    --override-base-url ${API_URL}

SIGNED_WILDCARD_CERTIFICATE="spinnaker.homedepot.com.cer"
WILDCARD_CERT_PRIVATE_KEY="wildcard.key"

hal config security ui ssl edit --ssl-certificate-file /${USER}/certs/"$SIGNED_WILDCARD_CERTIFICATE" --ssl-certificate-key-file /${USER}/certs/"$WILDCARD_CERT_PRIVATE_KEY"

# using expect to automate the required interactive password prompt
expect -c "spawn hal config security ui ssl edit --ssl-certificate-passphrase; sleep 1; expect -exact \"The passphrase needed to unlock your SSL certificate. This will be provided to Apache on startup.: \"; send -- \"nosecrets\r\"; expect eof"

expect -c "spawn hal config security api ssl edit --key-alias wildcard --keystore /spinnaker/certs/wildcard.jks --keystore-password --keystore-type jks --truststore /spinnaker/certs/wildcard.jks --truststore-password --truststore-type jks; sleep 1; expect -exact \"The password to unlock your keystore. Due to a limitation in Tomcat, this must match your key's password in the keystore.: \"; send -- \"nosecrets\r\"; expect -exact \"\rThe password to unlock your truststore.: \"; send -- \"nosecrets\r\"; expect eof"

hal config security api ssl enable
hal config security ui ssl enable


echo "You will need to do a hal deploy apply"