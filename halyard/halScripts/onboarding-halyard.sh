
%{ for deployment in deployments ~}
echo "Begining Spinnaker On-Boarding for deployment named ${deployment}"
hal config features edit --artifacts true --deployment ${deployment}
hal config artifact gcs enable --deployment ${deployment}
hal config artifact gcs account add --json-path $JSON_SA_KEY $ACCOUNT --deployment ${deployment}
hal config pubsub google enable --deployment ${deployment}
hal config pubsub google subscription add $SPIN_SUB_NAME \
  --project $PROJECT_NAME \
  --subscription-name $GCP_SUB_NAME \
  --message-format GCS \
  --json-path $JSON_SA_KEY \
  --deployment ${deployment}

echo "Running Spinnaker On-Boarding for deployment named ${deployment}"
hal deploy apply --deployment ${deployment}

%{ endfor ~}
