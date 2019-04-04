#!/bin/bash

check_pem_file() {
    if [ -L "$1.pem" ]; then
        echo "$1.pem appears to already be a symlink so nothing to do"
    else
        rm "$1.pem" && ln -s $(ls -t ../../archive/${DNS}/"$1"* | head -n1) "$1.pem"
        echo "removed $1.pem file and symlinked to latest archive file"
    fi
}

if [ -d /certbot/certbot/live/${DNS} ]; then
    cd /certbot/certbot/live/${DNS}
    check_pem_file "cert"
    check_pem_file "chain"
    check_pem_file "fullchain"
    check_pem_file "privkey"
else
    echo "certbot DNS directory for ${DNS} does not exist so nothing to do yet"
fi
