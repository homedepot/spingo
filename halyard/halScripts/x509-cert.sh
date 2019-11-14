
die() { echo "$*" 1>&2 ; exit 1; }
join_by() { local d=$1; shift; echo -n "$1"; shift; printf "%s" "$${@/#/$d}"; }

COUNTRY_CODE="$${COUNTRY_CODE:-US}"
STATE_CODE="$${STATE_CODE:-GA}"
CITY="$${CITY:-Atlanta}"
ORGANIZATION="$${ORGANIZATION:-Spingo}"

if [ -z "$COMMA_SEPERATED_GROUPS" ]; then
	die "A List of comma seperated groups is required to create the x509 certificate for those groups"
fi

IFS=', ' read -ra CERT_GROUPS <<<"$COMMA_SEPERATED_GROUPS"

if [ -z "$CERT_NAME" ]; then
	# a common name was not given so pulling the first group off of the array as the name
	CERT_NAME="$${CERT_GROUPS[0]}"
fi

JOINED_GROUPS=$(join_by "\n" "$${CERT_GROUPS[@]}")

if [ -f "/${USER}/x509/$${CERT_NAME}-client.crt" ]; then
  # TODO eventually, we should add a date validation for soon to be expiring certs
  echo "x509 certificate already exists, so exiting nicely"
  exit 0
else
  echo "x509 certificate does not exist so creating it"
  # Create the inital client key. We pass a password so it can continue without prompting
  openssl genrsa \
    -des3 \
    -out "/${USER}/x509/$${CERT_NAME}-client.key" \
    -passout pass:default \
    4096

  # Decrypt the client key and remove the password
  openssl rsa \
    -in "/${USER}/x509/$${CERT_NAME}-client.key" \
    -out "/${USER}/x509/$${CERT_NAME}-client.key" \
    -passin pass:default

  cat <<EOF > /${USER}/x509/$${CERT_NAME}-group.conf
 distinguished_name     = req_distinguished_name
 attributes             = req_attributes
 req_extensions = v3_req
 
 [ req_distinguished_name ]
 countryName                    = Country Name (2 letter code)
 countryName_min                        = 2
 countryName_max                        = 2
 stateOrProvinceName            = State or Province Name (full name)
 localityName                   = Locality Name (eg, city)
 0.organizationName             = Organization Name (eg, company)
 organizationalUnitName         = Organizational Unit Name (eg, section)
 commonName                     = Common Name (eg, fully qualified host name)
 commonName_max                 = 64
 emailAddress                   = Email Address
 emailAddress_max               = 64
 
 [ req_attributes ]
 challengePassword              = A challenge password
 challengePassword_min          = 4
 challengePassword_max          = 20
 
 [ v3_req ]
 keyUsage = nonRepudiation, digitalSignature, keyEncipherment
 1.2.840.10070.8.1 = ASN1:UTF8String:$${JOINED_GROUPS}

EOF

  # Generate a certificate signing request for the client
  openssl req \
    -new \
    -key "/${USER}/x509/$${CERT_NAME}-client.key" \
    -out "/${USER}/x509/$${CERT_NAME}-client.csr" \
    -subj "/C=$${COUNTRY_CODE}/ST=$${STATE_CODE}/L=$${CITY}/O=$${ORGANIZATION}/CN=$${CERT_NAME}@${DOMAIN}" \
    -config "/${USER}/x509/$${CERT_NAME}-group.conf"

  # Generate the x509 certificate
  openssl x509 \
    -req \
    -days 365 \
    -in "/${USER}/x509/$${CERT_NAME}-client.csr" \
    -CA /${USER}/certbot/${DNS_DOMAIN}_wildcard.crt \
    -CAkey /${USER}/certbot/${DNS_DOMAIN}_wildcard.key \
    -CAcreateserial \
    -out "/${USER}/x509/$${CERT_NAME}-client.crt" \
    -passin pass:${WILDCARD_KEYSTORE} \
    -extensions v3_req \
    -extfile "/${USER}/x509/$${CERT_NAME}-group.conf"

  openssl x509 \
    -in "/${USER}/x509/$${CERT_NAME}-client.crt" \
    -text

fi
