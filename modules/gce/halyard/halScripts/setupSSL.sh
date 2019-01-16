#!/bin/bash

kubectl -n spinnaker patch svc spin-deck --type=merge -p '{"spec": {"ports": [{"name": "http","port": 443,"targetPort": 9000},{"name": "monitoring","port": 8008,"targetPort": 8008}],"type": "LoadBalancer","loadBalancerIP": "'"${SPIN_UI_IP}"'"}}'
kubectl -n spinnaker patch svc spin-gate --type=merge -p '{"spec": {"ports": [{"name": "http","port": 443,"targetPort": 8084},{"name": "monitoring","port": 8008,"targetPort": 8008}],"type": "LoadBalancer","loadBalancerIP": "'"${SPIN_API_IP}"'"}}'

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