#!/usr/bin/env bash

if ! command -v shellcheck; then
	echo "shellcheck not found on this machine. Please install from https://www.shellcheck.net/"
	exit 1
fi

if ! command -v terraform; then
	echo "terraform not found on this machine. Please install from https://www.terraform.io"
	exit 1
fi

files="$(find . -regex '.*\.sh' -not -regex '.*halyard.*')"
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
