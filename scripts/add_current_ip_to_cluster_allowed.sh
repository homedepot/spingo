#!/usr/bin/env bash
function addIps(INSTANCE){
  CLUSTERNAME=$INSTANCE-$REGION
  list=gcloud container clusters describe $CLUSTERNAME | jq '.masterAuthorizedNetworksConfig.cidrBlocks[].cidrBlock' --region $REGION
  newlist=''
  for line in $list; do
    newlist = $newlist,$line
  done
  newlist=$newlist,$(curl ifconfig.co)/32
  gcloud container clusters update $CLUSTERNAME --enable-master-authorized-networks --master-authorized-networks $newlist --region $REGION
}

for instance in 'spinnaker sandbox'; do
  addIps($instance)
done
