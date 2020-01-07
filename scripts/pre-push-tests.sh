#!/usr/bin/env bash
## note: this is not meant to be run any way other than from the npmaile/spingo-sanity-check docker image. 
mkdir -p /spingo
cp -r /mnt/* /spingo

cd "/spingo" || { echo "if you see this message, a problem has occured"; exit 1; }

find . -regex-type sed -not -regex ".*\.(tf|sh)" -type f -delete

files="$(find . -type f -regex '.*\.sh' -not -regex '.*halyard.*')"
for file in $files; do
	echo "checking $file"
	if ! shellcheck "$file"; then
		echo "shellcheck failed for $file"
		exit 1
	fi
done

#setting up environment for terraform operations
export VAULT_ADDR="http://FakeVaultAddr:8200"
export VAULT_TOKEN="FakeVaultToken"
export VAULT_DEV_ROOT_TOKEN_ID="FakeDevRootTokenId"

tfdirs='static_ips
dns
monitoring-alerting
spinnaker
halyard'

for tfdir in $tfdirs; do
	cd "$tfdir" || { echo "failed to cd to $tfdir"; exit 1; }
	echo "checking terraform scripts in $tfdir"
	if ! terraform init -backend=false .; then
		echo "terraform init failed for $tfdir"
		exit 1
	fi
	if ! terraform validate; then
		echo "terraform validate failed for $tfdir"
		exit 1
	fi
	cd ..
done
echo "Pre-push validation complete. The repo should pass CI"
