#!/usr/bin/env bash
# shellcheck disable=SC2125,SC2068,SC2001
set -e
#I(N8) have no idea what the program does. I take no responsibility for it.
exists() {
    list=$1[@]
    name="$2"
    RESULT="false"
    arr=("${!list}")
    for item in ${arr[@]}
    do
        if [ "$item" == "$name" ]; then
            RESULT="true"
            break;
        fi
    done
    echo "$RESULT"
}
selected_clusters=()
PS3="-----------------------------------------------------------------------------"$'\n'"Enter the number for the Kubernetes Cluster to Add this machine's Ip to (Enter the number for Finished when done) : ";
select cluster in "$(gcloud container clusters list --format="value(name)")" Finished Cancel
do
    if [[ $cluster == "" ]]; then
        echo "You must choose a cluster"
    elif [ "$cluster" == "Finished" ]; then
        echo "Excellent selections!"
        break;
    elif [ "$cluster" == "Cancel" ]; then
        echo "Cancelling at user request"
        exit 1
    else
        do_exist=$(exists selected_clusters "$cluster")
        if [[ "$do_exist" == "true" ]] ; then
            echo "cluster already selected"
        else
            selected_clusters+=("$cluster")
            echo "adding cluster $cluster to selected clusters"
        fi
    fi
done

machinecidr="$(curl -s ifconfig.co)/32"
for cluster in ${selected_clusters[@]}
do
    location="$(gcloud beta container clusters list --filter="name:$cluster" --format="value(Location)")"
    cidrlist="$machinecidr"
    for cidr in $(gcloud container clusters describe "$cluster" --region "$location" --format="json" | jq '.masterAuthorizedNetworksConfig.cidrBlocks[].cidrBlock')
    do
        cidrlist="$cidrlist,$cidr"
    done
    cidrlist="$(echo "$cidrlist" | sed 's/\"//g')"
    gcloud container clusters update "$cluster" --enable-master-authorized-networks --master-authorized-networks "$cidrlist" --region "$location"
done
