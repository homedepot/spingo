# Spingo
<a id="markdown-spingo" name="spingo"></a>
A collection of Terraform and bash scripts to setup an enterprise-grade Spinnaker deployment on Google Cloud Platform

<!-- TOC -->

- [Spingo](#spingo)
    - [Architecture](#architecture)
    - [Prerequisites](#prerequisites)
    - [Quick Start](#quick-start)
        - [Setup Monitoring and Alerting](#setup-monitoring-and-alerting)
    - [Additional Information](#additional-information)
        - [Setup Managed DNS through Cloud DNS](#setup-managed-dns-through-cloud-dns)
        - [Google OAuth Authorization Setup](#google-oauth-authorization-setup)
        - [Google OAuth Authentication Setup](#google-oauth-authentication-setup)
        - [Slack Integration](#slack-integration)
    - [Restore saved values from vault](#restore-saved-values-from-vault)
    - [Teardown](#teardown)
    - [Contributing](#contributing)
    - [License](#license)

<!-- /TOC -->

## Architecture
<a id="markdown-architecture" name="architecture"></a>

![diagram](images/spingo-picture.png)

## Prerequisites
<a id="markdown-prerequisites" name="prerequisites"></a>

- [Vault](https://www.vaultproject.io/downloads.html) needs to be setup and authenticated
	- VAULT_ADDR environment variable should be setup pointing to the vault server
	- Or on OSX with homebrew it's `brew install vault`
	- A local vault initialization can be done by from scripts/local-vault-setup.sh
- [Google Cloud SDK](https://cloud.google.com/sdk/install) should be setup and authenticated
	- Be sure to run both `gcloud auth login` and `gcloud config set project <YOUR_PROJECT_ID>`
	- You will need to be an owner of the GCP project to grant all the permissions required for Terraform to create all the resources needed
- [Terraform](https://www.terraform.io/downloads.html) should be setup
	- Or on OSX with homebrew it's `brew install terraform`

## Quick Start
<a id="markdown-quick-start" name="quick-start"></a>

1. Navigate to https://github.com/homedepot/spingo/generate or click the green `Use this template` button above
1. Choose where you want to create your repo then clone it down
    - Hint: You can clone the repo from Google Cloud Shell for faster access to the Google APIs but you must have access to a Vault server to store/read the configuration info
1. Inside your clone of your repo run the following command:
    ```sh
    ./quickstart.sh
    ```
1. When asked to enter your Google OAuth credentials use [these instructions](#google-oauth-authentication-setup)
1. When asked to enter your Slack token use [these instructions](#if-you-are-going-to-use-slack-integration-skip-to-next-section-if-not) if you choose to setup Slack notifications or choose the option for `No`
1. When you see `Quickstart complete` you should see a Terraform output variable called `halyard_command` which you can copy to log into your ephemerial halyard VM
    - You should wait about 20 seconds or so for the VM to be up and running and ready to take commands before logging into it
1. Log into the halyard VM
1. Run the `showlog` command to follow the setup process by watching the tailing of the logs that setup all of the dependencies needed for all of the scripts inside the `quickstart` script
    - If you selected to auto run halyard `quickstart` during the initial quickstart then your Spinnaker should already be being setup
        - Once you see `Autostart complete please log into your Spinnaker deployment(s)` you can close out of `showlog` by pressing ctrl-c
    - If you selected to NOT auto run halyard `quickstart` then after you see `setup complete` you can close out of `showlog` by pressing ctrl-c
1. Run the `spingo` command to sudo into the shared user account
    - If you selected to NOT auto run halyard then after you see a user prompt like this `spinnaker@halyard-thd-spinnaker:~$` you will either need to run `./quickstart.sh` or run each of the pre-populated scripts that the `./quickstart` script is configured to run in that order
1. Once all the scripts are completed you should be able to log into Spinnaker and visit the [workloads page inside the Google Cloud Console](https://console.cloud.google.com/kubernetes/workload) and see all the Spinnaker kubernetes deployments by cluster

### Setup Monitoring and Alerting
<a id="markdown-setup-monitoring-and-alerting" name="setup-monitoring-and-alerting"></a>

Follow the instructions [here](monitoring-alerting) to setup basic monitoring and alerting of the Spinnaker deployments

## Additional Information
<a id="markdown-additional-information" name="additional-information"></a>

### Setup Managed DNS through Cloud DNS
<a id="markdown-setup-managed-dns-through-cloud-dns" name="setup-managed-dns-through-cloud-dns"></a>

After the managed DNS is setup you will need to direct the DNS hostname to the proper nameservers. After the DNS directory is run by quickstart, Terraform will output the new nameservers on the screen called `google_dns_managed_zone_nameservers = [ "ns-cloud-c1.googledomains.com.", "ns-cloud-c2.googledomains.com.", ...]`. You then need to log into your domain hosting provider and direct the owned domain to all four of these name servers so that traffic can be routed to your project and SSL certificates can be requested through the [Let's Encrypt](https://letsencrypt.org/) Google domain authentication plugin which adds a TXT record to the domain to prove that it is owned by you.

Once Google Cloud DNS is properly getting traffic you will be able to complete the Let's Encrypt SSL configuration.

### Google OAuth Authorization Setup
<a id="markdown-google-oauth-authorization-setup" name="google-oauth-authorization-setup"></a>

At the very end of the Setup Spinnaker Infrastructure step you will see an output called `spinnaker_fiat_account_unique_id` with a very large number printed out. That number is the unique ID of the Spinnaker service account `spinnaker-fiat` whose ID we need to use as the `Client Name` in step #3 when we follow [these instructions](https://www.spinnaker.io/setup/security/authorization/google-groups/#service-account-setup) to enable read-only permissions to get all the groups that a user has at the organization level. Many large enterprises sync their active directory groups to their Google user accounts and we want to utilize that to enable true Role Based Authentication (RBAC) within Spinnaker to separate authorizations between different applications and between different deployment targets.

This must happen before the `quickstart` script, that is run from inside the halyard VM, is run otherwise you will not be able to log into Spinnaker successfully

### Google OAuth Authentication Setup
<a id="markdown-google-oauth-authentication-setup" name="google-oauth-authentication-setup"></a>

- Navigate to the [APIs & Services > Credentials](https://console.cloud.google.com/apis/credentials/consent) and set your `Application name` and your `Authorized domains`
- Navigate to [Create OAuth client ID](https://console.cloud.google.com/apis/credentials/oauthclient) and choose `Web application` then enter the `Name` like `spinnaker client ID` and the `Authorized redirect URIs` to your HTTPS urls like this (note the `/login` at the end of each
	- `https://np-api.demo.example.com/login`
	- `https://sandbox-api.demo.example.com/login`
- Write your new OAuth client ID and client secret into vault
	- You can enter the details directly through this command	`vault write secret/$(gcloud config list --format 'value(core.project)' 2>/dev/null)/gcp-oauth "client-id=replace-me" "client-secret=replace-me"`
	- Alternatively, you may be able to use the vault UI and enter the information to the same location and replace anything where the value is `replace-me`

### Slack Integration
<a id="markdown-slack-integration" name="slack-integration"></a>

- Create a [Slack Bot App](https://api.slack.com/apps) within your Slack workspace and call it `spinnakerbot`
- Under the `OAuth & Permissions` section make sure that the `bot` scope is listed under interactivity and copy your `Bot User OAuth Access Token`
- Write your new `Bot User OAuth Access Token`
	- You can enter the details directly through this command	 `vault write secret/$(gcloud config list --format 'value(core.project)' 2>/dev/null)/slack-token "value=replace-me"`
	- Alternatively, you may be able to use the vault UI and enter the information to the same location and replace anything where the value is `no-slack`


## Restore saved values from vault
<a id="markdown-restore-saved-values-from-vault" name="restore-saved-values-from-vault"></a>

If you have previously run `./quickstart.sh`, and are in a situation where this is a new machine or otherwise a fresh clone of the repo, you can restore the saved values from vault by running:

```sh
scripts/restore-saved-config-from-vault.sh
```

## Teardown
<a id="markdown-teardown" name="teardown"></a>

If you want to completely destroy the installation:

1. execute `./scripts/reset-spingo.sh`, after confirmation, it will destroy all Terraform resources and the service accounts and buckets that Terraform requires so that the `./scripts/initial-setup.sh` can be run again if needed.

## Contributing
<a id="markdown-contributing" name="contributing"></a>

Check out the [contributing](CONTRIBUTING.md) readme for information on how to contribute to the project.

## License
<a id="markdown-license" name="license"></a>

This project is released under the Apache2 free software license. More information can be found in the [LICENSE](LICENSE) file.
