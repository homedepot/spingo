#!/usr/bin/env bash
vaultdir="$HOME/vault"
mkdir $vaultdir

wget -O "$vaultdir/vault.zip" "https://releases.hashicorp.com/vault/1.2.3/vault_1.2.3_linux_amd64.zip"
unzip "$vaultdir/vault.zip" $vaultdir/vault

sudo ln -s "$vaultdir/vault" "/usr/bin/vault"

echo "storage \"file\" {
address = \"127.0.0.1:8500\"
path = \"$vaultdir/secrets\"
}
disable_mlock = true
listener \"tcp\" {
address = \"127.0.0.1:8200\"
tls_disable = 1
}" > $vaultdir/config.hcl

vault server --config "$vaultdir/config.hcl" >/dev/null &

export VAULT_ADDR="http://127.0.0.1:8200"
vault operator init -n 1 -t 1 > "$vaultdir/initinfo"

echo $vaultdir/initinfo | sed -n -e 's/Unseal Key 1:\s\(.*\)$/\1/p' 
#| xargs vault operator unseal
echo $vaultdir/initinfo | sed -n -e 's/Initial Root Token:\s\(.*\)$\1/p' 
#| vault login -
