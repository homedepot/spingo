#!/usr/bin/env bash
set -e
vaultdir="$HOME/vault"
mkdir -p $vaultdir
if [ ! "$(command -v vault)" ]; then
echo "downloading Vault for Linux"
wget -O "$vaultdir/vault.zip" "https://releases.hashicorp.com/vault/1.2.3/vault_1.2.3_linux_amd64.zip"
unzip "$vaultdir/vault.zip" $vaultdir/vault
sudo ln -s "$vaultdir/vault" "/usr/bin/vault"
fi

if [ ! -f $vaultdir/config.hcl ]; then
echo "generating config.hcl file"

tee $vaultdir/config.hcl << CONFIGURATION
storage "file" {
	address = "127.0.0.1:8500"
	path = "$vaultdir/secrets"
}
disable_mlock = true
listener "tcp" {
	address = "127.0.0.1:8200"
	tls_disable = 1
}
CONFIGURATION
fi

vault server --config "$vaultdir/config.hcl" >/dev/null &

if [ "$VAULT_ADDR" != "http://127.0.0.1:8200" ]; then
	export VAULT_ADDR_NOT_SET="true"
fi

export VAULT_ADDR="http://127.0.0.1:8200"
vault operator init -n 1 -t 1 > "$vaultdir/initinfo"
cat $vaultdir/initinfo | sed -n -e 's/Unseal Key 1: \(.*\)$/\1/p' | xargs vault operator unseal
cat $vaultdir/initinfo | sed -n -e 's/Initial Root Token: \(.*\)$/\1/p' | vault login -

echo "vault should be set up now"

if [ -n $VAULT_ADDR_NOT_SET ]; then
	echo "please set \$VAULT_ADDR to \"http://127.0.0.1:8200\""
fi

