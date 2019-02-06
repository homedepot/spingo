#!/bin/bash

./home/${USER}/setupK8SSL.sh

hal config security ui edit \
    --override-base-url ${UI_URL}
    #--override-base-url https://spinnaker.np-platforms-cd-thd.gcp.homedepot.com

hal config security api edit \
    --override-base-url ${API_URL}
   # --override-base-url https://spinnaker-api.np-platforms-cd-thd.gcp.homedepot.com

hal config security ui ssl edit --ssl-certificate-file /${USER}/certbot/wildcard.crt --ssl-certificate-key-file /${USER}/certbot/wildcard.key

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