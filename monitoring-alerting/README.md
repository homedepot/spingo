# Stackdriver Monitoring and Alerting

This terraform module is designed to setup some basic monitoring and alerting through Stackdriver to let an operator know when the following events happen:
- API service (gate for each configured cluster) cannot be reached for more than 5 minutes
- Google Memorystore (Redis) gets less than 200 calls per second for 3 minutes or more
- Google CloudSQL gets less than 20 calls per second for 3 minutes or more
- Google CloudSQL Failover Replica lags 60 seconds for 1 minute or more

## Setup Notification Channels
Using the UI, you can setup notification channels as below: 

For Slack go to 
https://app.google.stackdriver.com/settings/accounts/notifications/slack

For PagerDuty go to
https://app.google.stackdriver.com/settings/accounts/notifications/pagerduty

For SMS go to
https://app.google.stackdriver.com/settings/accounts/notifications/sms

For Email...
Unfortunately, you need to setup an Alert Policy first then you can edit the policy and add an email account which will create the email notification channel that can then be selected

## Choose Notification Channels
After you have setup all the notification channels you want alerted during outages then execute the `./setupNotificationChannels.sh` script to install the gcloud alpha components (if needed) and choose which of the configured notification channels you would like to use for the default alerting.

Currently, every notification channel will be triggered by any alert simultaneously.

## Initialize and Apply Terraform

```sh
# Initialize Terraform against newly created bucket
terraform init
terraform apply
```

Spingo will retrieve information about the CloudSQL and Memorystore instances from the Terraform remote backend state storage and create the appropriate uptime checks and policy alerts
