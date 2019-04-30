# Spingo
A collection of Terraform and bash scripts to setup an enterprise-grade Spinnaker deployment on Google Cloud Platform

## Prerequisites

- [Vault](https://www.vaultproject.io/downloads.html) needs to be setup and authenticated
	- VAULT_ADDR environment variable should be setup pointing to the vault server
	- Or on OSX with homebrew it's `brew install vault`
- [Google Cloud SDK](https://cloud.google.com/sdk/install) should be setup and authenticated
	- Be sure to run both `gcloud auth login` and `gcloud config set project <YOUR_PROJECT_ID>`
	- You will need to be an owner of the GCP project to grant all the permissions required for Terraform to create all the resources needed
- [Terraform](https://www.terraform.io/downloads.html) should be setup
	- Or on OSX with homebrew it's `brew install terraform`

## Setup

### Initialize

```sh
git clone https://github.com/homedepot/spingo.git
cd spingo
./scripts/01-create-terraform-service-account.sh
cd ..
```

### Setup Managed DNS through Cloud DNS

```sh
cd dns
# Initialize Terraform against newly created bucket
terraform init
terraform apply
cd ..
```

### Setup Spinnaker Infrastructure

```sh
cd spinnaker
# Initialize Terraform against newly created bucket
terraform init
terraform apply
cd ..
```

### Setup Halyard VM

#### If you are going to use Google OAuth (skip to next section if not)

- Navigate to the [APIs & Services > Credentials](https://console.cloud.google.com/apis/credentials/consent) and set your `Application name` and your `Authorized domains`
- Naivate to [Create OAuth client ID](https://console.cloud.google.com/apis/credentials/oauthclient) and choose `Web application` then enter the `Name` like `spinnaker client ID` and the `Authorized redirect URIs` to your HTTPS url like this (note the `/login` at the end of each
	- `https://spinnaker-api.demo.example.com/login`
- Write your new OAuth client ID and client secret into vault
	- You can enter the details directly through this command	`vault write secret/$(gcloud config list --format 'value(core.project)' 2>/dev/null)/gcp-oauth "client-id=replace-me" "client-secret=replace-me"`
	- Alternatively, you may be able to use the vault UI and enter the information to the same location and replace anything where the value is `replace-me`

#### If you are going to use Slack integration (skip to next section if not)

- Create a [Slack Bot App](https://api.slack.com/apps) within your Slack workspace and call it `spinnakerbot`
- Under the `OAuth & Permissions` section make sure that the `bot` scope is listed under interactivity and copy your `Bot User OAuth Access Token`
- Write your new `Bot User OAuth Access Token`
	- You can enter the details directly through this command	 `vault write secret/$(gcloud config list --format 'value(core.project)' 2>/dev/null)/slack-token "value=replace-me"`
	- Alternatively, you may be able to use the vault UI and enter the information to the same location and replace anything where the value is `replace-me`

#### Certbot SSL through Let's Encrypt

```sh
cd certbot
# Initialize Terraform against newly created bucket
terraform init
terraform apply
```

- SSH into the [certbot VM](https://console.cloud.google.com/compute/instances)
- Enter this command to make sure the setup is complete `showlog`
- Once completed, log into the user account by entering this command `spingo`
- Test create a certificate by executing this script `./execute-test.sh`
- When you are ready to create the certificate for real then execute this script `./execute-only-if-you-are-sure.sh`
- When you have successfully recieved certificates you then execute `./make_or_update_keystore.sh`
- Finally, you run the command `pushcerts` to push the certs back up to the halyard bucket
- You no longer need the certbot VM anymore so destroy it

```sh
terraform destroy
cd ..
```

#### It's Halyard Time!

```sh
cd halyard
# Initialize Terraform against newly created bucket
terraform init
terraform apply
```

- SSH into the [halyard VM](https://console.cloud.google.com/compute/instances)
- Enter this command to make sure the setup is complete `showlog`
- Once completed log into the user account by entering this command `spingo`
- Setup Halyard for the first time by executing `./setupHalyard.sh`
- We need to replace the IP addresses in the `default_networks_that_can_access_k8s_api` variable of the `vars.tfvars` file in the root directory to be the correct values that were previously created. They are marked with comments on where to change them and which should go where. Then we need to do a `terraform apply` in the `spinnaker` directory to make the changes take effect. (This will almost certainly get automated in the future but for now...)
- Before we deploy we should make sure we can reach the cluster by trying this command `kubectl get nodes` and you should see the nodes of the cluster listed
- Now we need to deploy Spinnaker with the `hda` command which behind the scenes runs `hal deploy apply --wait-for-completion`
- Once the deployment is successful the next step is to setup SSL by executing `./setupSSL.sh`
- Last step is to do a `hda` to send the full configuration up to the Spinnaker deployment
- Navigate to your new Spinnaker by going to `https://spinnaker.demo.example.com` and replacing `demo.example.com` with whatever domain you entered into the initialization script
