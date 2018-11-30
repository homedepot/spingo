# Spinnaker terraform bootsatrap scripts

## requirements

### vault

In order for this to work properly, you must be logged-in to vault,

```shell
export VAULT_ADDR=https://vault.ioq1.homedepot.com:10231
vault login <your token>
```

### gcloud

You must also be logged into your gcloud account

```shell
gcloud auth login
```

## bootstrapping (one-time step)

The terraform service account must be created prior to running any terraform commands:

```shell
scripts/01-create-terraform-service-account.sh
```

## terraform

```shell
terraform init
terraform plan
terraform apply
```