# Certificate Handling

## SSL Certificates

Run `./pre-ca.sh` to generate certificate request and submit it to the [certificate request form](https://portal.homedepot.com/sites/IT_Encryption/Lists/SSL%20Certificate%20Intake%20Database1/AllItems.aspx)

After the signed certificate is returned:

* Modify `post-ca.sh` and enter the proper passwords for `WILDCARD_KEY_PASSWORD` & `JKS_PASSWORD`
* Run `post-ca.sh` to generate the keystore file and upload the files to the GCP bucket

## SAML Certificates

* Edit [create-saml-keystore.sh](create-saml-keystore.sh) and set the `PASS` environment variable to the appropriate value
* Run `./create-saml-keystore.sh` with the spinnaker name as the argument (e.g. `sandbox` or `np`: `./create-saml-keystore.sh np`)
* The script will generate a java keystore (`.jks`) file and extracted certificate file (`.cer`) file and upload them to the appropriate GCP Bucket
* Provide the SAML administrators (IAM_SSO_Management@homedepot.com) the extracted `.cer` file to add to the appropriate SAML partnership
