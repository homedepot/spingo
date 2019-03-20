# Certificates handling

Run `pre-ca.sh` to generate certificate request and submit it to the [certificate request form](https://portal.homedepot.com/sites/IT_Encryption/Lists/SSL%20Certificate%20Intake%20Database1/AllItems.aspx)

After the signed certificate is returned:

* Modify `post-ca.sh` and enter the proper passwords for `WILDCARD_KEY_PASSWORD` & `JKS_PASSWORD`
* Run `post-ca.sh` to generate the keystore file and upload the files to the GCP bucket
