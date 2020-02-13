#!/bin/bash

if [ ! -d /${USER}/metrics ]; then
  mkdir /${USER}/metrics
fi


%{ for deployment, details in deployments ~}

echo "Creating monitoring namespace for deployment ${deployment}"

kubectl --kubeconfig="${details.kubeConfig}" create namespace monitoring

echo "${details.metricsYaml}" | base64 -d > /${USER}/metrics/metrics_${details.clusterName}_helm_values.yml

echo -e "Creating grafana dashboards as ConfigMaps for deployment ${deployment}\n"

git clone https://github.com/spinnaker/spinnaker-monitoring.git
CWD=$(pwd)
cd spinnaker-monitoring/spinnaker-monitoring-third-party/third_party/prometheus_operator
sed -i grafana-dashboard.yaml.template -e "s/  name: %DASHBOARD%/  name: %DASHBOARD%\n  namespace: monitoring/"

ROOT="$( cd "$( dirname "$${BASH_SOURCE[0]}" )" && pwd )"

for filename in "$ROOT"/../prometheus/*-dashboard.json; do
  fn_only=$(basename "$filename")
  fn_root="$${fn_only%.*}"
  dest_file="generated_dashboards/$${fn_root}.yaml"
  uid=$(uuidgen)

  cat grafana-dashboard.yaml.template | sed -e "s/%DASHBOARD%/$fn_root/" > $dest_file
  printf "  $fn_only: |-\n" >> $dest_file

  cat $filename | sed -e "s/\"uid\": null/\"uid\": \"$${uid}\"/" \
    | sed -e "/\"__inputs\"/,/],/d" \
      -e "/\"__requires\"/,/],/d" \
      -e "s/\$${DS_SPINNAKER\}/Prometheus/g" \
      -e "s/^/    /" \
  >> $dest_file
done

echo "Applying dashboards as configmaps to cluster..."

kubectl --kubeconfig="${details.kubeConfig}" --namespace monitoring apply -f generated_dashboards

cd "$CWD"

echo "Enabling metric-stored in halyard"

hal config metric-stores prometheus enable --deployment ${deployment}

echo "deploying metric-enabled spinnaker"

hal deploy apply


echo "Starting up prometheus-operator through helm for deployment ${deployment}"


helm init \
    --service-account tiller \
    --kubeconfig "${details.kubeConfig}" \
    --history-max 200

helm install \
    --name spin \
    --namespace monitoring \
    --kubeconfig "${details.kubeConfig}" \
    --values /${USER}/metrics/metrics_${details.clusterName}_helm_values.yml \
    stable/prometheus-operator

%{ endfor ~}
