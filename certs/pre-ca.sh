#!/bin/bash

WILDCARD_CERT_PRIVATE_KEY="wildcard.key"
SAN_FILE=san.cnf

openssl req -newkey rsa:2048 -nodes -out sslcert.csr -keyout ${WILDCARD_CERT_PRIVATE_KEY} -config ${SAN_FILE}

echo "submit sslcert.csr to certificate request form: https://portal.homedepot.com/sites/IT_Encryption/Lists/SSL%20Certificate%20Intake%20Database1/AllItems.aspx"
