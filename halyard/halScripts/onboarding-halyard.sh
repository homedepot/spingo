
%{ for deployment, details in deployments ~}
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

echo "Creating Gate x509 API Service for deployment named ${deployment}"
cat <<SVC_EOF | kubectl --kubeconfig="${details.kubeConfig}" apply -f -
apiVersion: v1
kind: Service
metadata:
  labels:
    app: spin
    cluster: spin-gate
  name: spin-gate-spin-api
  namespace: spinnaker
spec:
  loadBalancerIP: ${details.clientIP}
  ports:
  - port: 443
    protocol: TCP
    targetPort: 8085
  selector:
    app: spin
    cluster: spin-gate
  sessionAffinity: None
  type: LoadBalancer
SVC_EOF

echo "Added Gate x509 API Service for deployment named ${deployment}"
hal config security authn x509 edit --role-oid 1.2.840.10070.8.1 --deployment ${deployment}
hal config security api ssl edit --client-auth WANT --deployment ${deployment}
hal config security authn x509 enable --deployment ${deployment}

echo "Adding x509 API port to gate-local for deployment named ${deployment}"
cat <<EOF >> /${USER}/.hal/${deployment}/profiles/gate-local.yml

default:
  apiPort: 8085
EOF

if [ ! -d /${USER}/.spin ]; then
  mkdir /${USER}/.spin
fi

/home/${USER}/createX509.sh

cat <<EOF > /${USER}/.spin/${deployment}.config
gate:
  endpoint: https://${details.clientHostnames}
auth:
  enabled: true
  x509:
    certPath: "/${USER}/x509/$${CERT_NAME}-client.crt"
    keyPath: "/${USER}/x509/$${CERT_NAME}-client.key"
EOF

echo "Adding Spinnaker On-Boarding for deployment named ${deployment}"
hal deploy apply \
    --deployment ${deployment} \
    --wait-for-completion # we need to wait for the deployment to complete so that fiat exists

echo "Adding Fiat Service account used by On-Boarding for deployment named ${deployment}"
update_kube "${deployment}"
update_spin "${deployment}"

/home/${USER}/createFiatServiceAccount.sh --role "${ADMIN_GROUP}"

echo "Waiting for Gate to be up and running for deployment ${deployment}"
n=0
until [ $n -ge 20 ]
do
  kubectl -n spinnaker get po -l=app.kubernetes.io/name=gate \
  --kubeconfig="/${USER}/.kube/${deployment}.config" \
  -o=jsonpath='{.items[*].status.containerStatuses[*].ready}' | grep -v "false" && break
   n=$((n+1))
   echo "Gate is not yet up and running for deployment ${deployment} waiting..."
   sleep 6
done

n=0
until [ $n -ge 60 ]
do
   ATTEMPT="success"
   spin application save --file=/home/${USER}/spingoAdminApplication.json && break
   ATTEMPT="fail"
   n=$((n+1))
   echo "Unable to create application through x509 cert for deployment ${deployment} retrying..."
   sleep 6
done

if [ "$ATTEMPT" == "success" ]; then
    n=0
    until [ $n -ge 20 ]
    do
        ATTEMPT="success"
        spin pipeline save --file=/home/${USER}/onboardingNotificationsPipeline.json && break
        ATTEMPT="fail"
        n=$((n+1))
        echo "Unable to create pipeline through x509 cert for deployment ${deployment} retrying..."
        sleep 6
    done
else
    echo "Unable to add pipeline becuase application was unable to save"
fi

%{ endfor ~}
