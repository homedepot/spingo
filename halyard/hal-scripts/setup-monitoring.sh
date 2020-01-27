#!/bin/bash

echo "configuring prometheus for spinnaker"
git clone https://github.com/spinnaker/spinnaker-monitoring.git
CWD=$(pwd)
cd spinnaker-monitoring/spinnaker-monitoring-third-party/third_party/prometheus_operator
echo "metadata.namespace: spinnaker" | yq write -s - -i spinnaker-service-monitor.yaml
sed -i grafana-dashboard.yaml.template -e "s/  name: %DASHBOARD%/  name: %DASHBOARD%\n  namespace: monitoring/"
./setup.sh
cd "$CWD"

hal config metric-stores prometheus enable
echo "-----------------------------------------------------------------------------"
echo "Metrics enabled, you should now execute the hda command to push the changes"
