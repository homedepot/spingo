#!/bin/bash

CLIENT_ID="${OAUTH_CLIENT_ID}"
CLIENT_SECRET="${OAUTH_CLIENT_SECRET}"
PROVIDER=google

hal config security authn oauth2 edit \
  --client-id $CLIENT_ID \
  --client-secret $CLIENT_SECRET \
  --provider $PROVIDER
hal config security authn oauth2 enable

hal config security authn oauth2 edit --pre-established-redirect-uri ${API_URL}/login


ADMIN="${ADMIN_EMAIL}"              # An administrator's email address
CREDENTIALS=/${USER}/.gcp/spinnaker-fiat.json   # The downloaded service account credentials
DOMAIN="${DOMAIN}"                   # Your organization's domain.
   
hal config security authz google edit \
    --admin-username $ADMIN \
    --credential-path $CREDENTIALS \
    --domain $DOMAIN
   
hal config security authz edit --type google
   
hal config security authz enable

