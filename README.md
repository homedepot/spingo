# Spinnaker terraform bootstrap

## requirements

### vault

<img src="https://s3.amazonaws.com/hashicorp-marketing-web-assets/brand/Vault_PrimaryLogo_FullColor.HkwAATB6e.svg" width="100" height="100">

In order for this to work properly, you must be logged-in to vault,

```shell
export VAULT_ADDR=https://vault.ioq1.homedepot.com:10231
vault login <your token>
```

### gcloud

<img src="https://www.gstatic.com/images/branding/product/2x/cloud_512dp.png" width="100" height="100">

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

<img src="https://s3.amazonaws.com/hashicorp-marketing-web-assets/brand/Terraform_VerticalLogo_FullColor.B1rgyCrag.svg" width="100" height="100">

<TBD>

```shell
terraform init
terraform plan
terraform apply
```
