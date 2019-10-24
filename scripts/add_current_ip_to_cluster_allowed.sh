#!/usr/bin/env bash
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
selected_channels=()
PS3="-----------------------------------------------------------------------------"$'\n'"Enter the number for the Kubernetes Cluster to Add this machine's Ip to (Enter the number for Finished when done) : ";
select channel in $(gcloud container clusters list --format="value(name)") Finished Cancel
do
    if [[ $channel == "" ]]; then
        echo "You must choose a cluster"
    elif [ "$channel" == "Finished" ]; then
        echo "Excellent selections!"
        break;
    elif [ "$channel" == "Cancel" ]; then
        echo "Cancelling at user request"
        exit 1
    else
        do_exist=$(exists selected_channels "$channel")
        if [[ "$do_exist" == "true" ]] ; then
            echo "cluster already selected"
        else
            selected_channels+=($channel)
            echo "adding channel $channel to selected channels"
        fi
    fi
done

for cluster in ${selected_channels[@]}
do
  location=$(gcloud beta container clusters list --filter="name:$cluster" --format="value(Location)")
  for cidr in $(gcloud container clusters describe $cluster --region $location --format="json" | jq '.masterAuthorizedNetworksConfig.cidrBlocks[].cidrBlock'); do
    cidrlist=$cidrlist,$cidr
  done
  cidrlist=$(curl -s ifconfig.co)/32$cidrlist
  cidrlist=$(echo $cidrlist | sed s/\"//g)
  gcloud container clusters update $cluster --enable-master-authorized-networks --master-authorized-networks $cidrlist --region $location
  #the next line clears the variable before the next loop. don't touch it!
  cidrlist= 
done
