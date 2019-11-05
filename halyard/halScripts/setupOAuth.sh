
CLIENT_ID="${OAUTH_CLIENT_ID}"
CLIENT_SECRET="${OAUTH_CLIENT_SECRET}"
PROVIDER=google
DOMAIN="${DOMAIN}"                   # Your organization's domain.
ADMIN="${ADMIN_EMAIL}"              # An administrator's email address
CREDENTIALS=/${USER}/.gcp/spinnaker-fiat.json   # The downloaded service account credentials

if [[ "$CLIENT_ID" != "replace-me" ]]; then
    echo "Adding Spinnaker Google OAuth Authentication for deployment named ${deployment}"
    hal config security authn oauth2 edit \
        --client-id "$CLIENT_ID" \
        --client-secret "$CLIENT_SECRET" \
        --provider "$PROVIDER" \
        --user-info-requirements hd="$DOMAIN" \
        --deployment ${DEPLOYMENT_NAME}
    hal config security authn oauth2 enable \
        --deployment ${DEPLOYMENT_NAME}

    hal config security authn oauth2 edit \
        --pre-established-redirect-uri ${API_URL}/login \
        --deployment ${DEPLOYMENT_NAME}
      
    hal config security authz google edit \
        --admin-username "$ADMIN" \
        --credential-path "$CREDENTIALS" \
        --domain "$DOMAIN" \
        --deployment ${DEPLOYMENT_NAME}
      
    hal config security authz edit \
        --type google \
        --deployment ${DEPLOYMENT_NAME}
      
    hal config security authz enable \
        --deployment ${DEPLOYMENT_NAME}

    echo "Added Spinnaker Google OAuth for deployment named ${deployment}"
else
    echo "No Google OAuth Client ID found so skipping setting up Google OAuth Authentication for deployment named ${deployment}"
fi
