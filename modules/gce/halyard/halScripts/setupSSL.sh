#!/bin/bash

./home/${USER}/setupK8SSL.sh

hal config security ui edit \
    --override-base-url ${UI_URL}

hal config security api edit \
    --override-base-url ${API_URL}

hal config security ui ssl edit --ssl-certificate-file /${USER}/certbot/wildcard.crt --ssl-certificate-key-file /${USER}/certbot/wildcard.key

# using expect to automate the required interactive password prompt
expect -c "spawn hal config security ui ssl edit --ssl-certificate-passphrase; sleep 1; expect -exact \"The passphrase needed to unlock your SSL certificate. This will be provided to Apache on startup.: \"; send -- \"nosecrets\r\"; expect eof"

# TODO: do the expect thing below so we don't need to manually type in the password
echo "You will need to type nosecrets in 2 times."

#You will have to type nosecrets passcode in twice
KEYSTORE_PATH=/${USER}/certbot/wildcard.jks
hal config security api ssl edit --key-alias ${USER} \
  --keystore $KEYSTORE_PATH --keystore-password \
  --keystore-type jks --truststore $KEYSTORE_PATH \
  --truststore-password --truststore-type jks
hal config security api ssl enable
hal config security ui ssl enable


echo "You will need to do a hal deploy apply"