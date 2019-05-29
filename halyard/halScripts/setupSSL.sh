#!/bin/bash

./setupK8SSL.sh

hal config security ui edit \
    --override-base-url ${UI_URL}

hal config security api edit \
    --override-base-url ${API_URL}

SIGNED_WILDCARD_CERTIFICATE="${DNS}_wildcard.crt"
WILDCARD_CERT_PRIVATE_KEY="${DNS}_wildcard.key"
WILDCARD_KEYSTORE="${DNS}_wildcard.jks"

hal config security ui ssl edit --ssl-certificate-file /${USER}/certbot/"$SIGNED_WILDCARD_CERTIFICATE" --ssl-certificate-key-file /${USER}/certbot/"$WILDCARD_CERT_PRIVATE_KEY"

# using expect to automate the required interactive password prompt
expect -c "spawn hal config security ui ssl edit --ssl-certificate-passphrase; sleep 1; expect -exact \"The passphrase needed to unlock your SSL certificate. This will be provided to Apache on startup.: \"; send -- \"${KEYSTORE_PASS}\r\"; expect eof"

expect -c "spawn hal config security api ssl edit --key-alias spinnaker --keystore /${USER}/certbot/$WILDCARD_KEYSTORE --keystore-password --keystore-type jks --truststore /${USER}/certbot/$WILDCARD_KEYSTORE --truststore-password --truststore-type jks; sleep 1; expect -exact \"The password to unlock your keystore. Due to a limitation in Tomcat, this must match your key's password in the keystore.: \"; send -- \"${KEYSTORE_PASS}\r\"; expect -exact \"\rThe password to unlock your truststore.: \"; send -- \"${KEYSTORE_PASS}\r\"; expect eof"

hal config security api ssl enable
hal config security ui ssl enable

echo "You will need to do a hal deploy apply"
