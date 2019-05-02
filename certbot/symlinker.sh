#!/bin/bash

cwd=$(pwd)

check_pem_file() {
    if [ -L "$2/$1.pem" ]; then
        echo "$2/$1.pem appears to already be a symlink so nothing to do"
    else
        if [ -d ../archive/"$2" ]; then
            rm "$2/$1.pem" && ln -s ../$(ls -t ../archive/"$2"/"$1"* | head -n1) "$2/$1.pem"
            echo "removed $1.pem file and symlinked to latest archive file for domain $2"
        else
            echo "There seems to be a $1 file in the live directory for the domain but not in the archive directory so something is very worng for domain $2"
        fi
    fi
}

if [ -d /certbot/certbot/live ]; then
    cd /certbot/certbot/live
    for dir in $(ls -d */)
    do
        clean_dir="$${dir%%/}" # use the double $ to scape terraform interpolation
        check_pem_file "cert" "$clean_dir"
        check_pem_file "chain" "$clean_dir"
        check_pem_file "fullchain" "$clean_dir"
        check_pem_file "privkey" "$clean_dir"
    done
else
    echo "certbot DNS directories do not exist so nothing to do yet"
fi
cd "$cwd"
