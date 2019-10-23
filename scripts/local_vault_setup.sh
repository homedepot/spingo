#!/usr/bin/env bash
set -e
vaultdir="$HOME/vault"
if [[ "$VAULT_ADDR" != "http://127.0.0.1:8200" ]]; then
  export VAULT_ADDR_NOT_SET="true"
  export VAULT_ADDR="http://127.0.0.1:8200"
fi

mkdir -p $vaultdir

#if vault not installed, install vault

if [[ ! "$(command -v vault)" ]]; then
  case "$(uname)" in
    "Darwin")
      echo "attempting to download Vault for macos"
      brew install vault
      ;;
    "Linux")
      echo "downloading Vault for Linux"
      wget -O "$vaultdir/vault.zip" "https://releases.hashicorp.com/vault/1.2.3/vault_1.2.3_linux_amd64.zip"
      unzip "$vaultdir/vault.zip" -d $vaultdir/vault
      sudo ln -s "$vaultdir/vault" "/usr/bin/vault"
      ;;
  esac
fi

#if no config, make config
if [[ ! -f $vaultdir/config.hcl ]]; then
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
#if not running, run
if [[ $(vault status 2>&1 | grep "connection refused") ]]; then
  vault server --config "$vaultdir/config.hcl" >/dev/null 2>&1 &
  sleep 5
fi

# if no initinfo, initialize and write to file
if [[ ! -f $vaultdir/initinfo ]]; then
  vault operator init -n 1 -t 1 > "$vaultdir/initinfo"
fi

# if sealed, unseal
if [[ $(vault status | grep "^Sealed.*true$") ]]; then
  cat $vaultdir/initinfo | sed -n -e 's/Unseal Key 1: \(.*\)$/\1/p' | xargs vault operator unseal
fi

# login
cat $vaultdir/initinfo | sed -n -e 's/Initial Root Token: \(.*\)$/\1/p' | vault login -

vault status
echo "vault should be set up now"

if [[ -n $VAULT_ADDR_NOT_SET ]]; then
  echo -e "please set \$VAULT_ADDR to \"http://127.0.0.1:8200\" by running the command on the next line\nexport VAULT_ADDR=\"http://127.0.0.1:8200\"\n"
fi

