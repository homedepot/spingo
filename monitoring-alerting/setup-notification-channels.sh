#!/bin/bash
# shellcheck disable=SC2198,SC2068
die() { echo "$*" 1>&2 ; exit 1; }

need() {
    command -v "$1" &>/dev/null || die "Binary '$1' is missing but required"
}

exists() {
    list="$1[@]" #cannot pass array to function, they just come in as literals. indirect expansion done below
    name="$2"
    RESULT="false"

    for item in "${!list}" #indirect expansion done here. "${!list}" expands to "$first_arg[@]"
    do
        if [ "$item" == "$name" ]; then
            RESULT="true"
            break;
        fi
    done
    echo "$RESULT"
}

need "gcloud"
need "jq"

if ! gcloud components install alpha --quiet
then
    die "Unable to install gcloud alpha components required to manage notification channels"
fi

gcloud alpha monitoring channels list --format='table[box](name, type,labels.number,labels.channel_name,labels.email_address)'

selected_channels=()
PS3="-----------------------------------------------------------------------------"$'\n'"Enter the number for the notification channel to setup (Enter the number for Finished when done) : ";
select channel in $(gcloud alpha monitoring channels list --format="value(name)") Finished Cancel
do
    if [[ $channel == "" ]]; then
        echo "You must choose a notification channel"
    elif [ "$channel" == "Finished" ]; then
        if [ -z "${selected_channels[@]}" ]; then
            echo "You need to make at least one selection before choosing finished"
        else
            echo "Excellent selections!"
            break;
        fi
    elif [ "$channel" == "Cancel" ]; then
        echo "Cancelling at user request"
        exit 1
    else
        do_exist=$(exists selected_channels "$channel")
        if [[ "$do_exist" == "true" ]] ; then
            echo "Channel already selected"
        else
            selected_channels+=("$channel")
            echo "adding channel $channel to selected channels"
        fi
    fi
done

variable="notification_channels = ["
delim=""
for chan in ${selected_channels[@]}
do
    variable+="$delim\"$chan\""
    delim=","
done
variable+="]"
echo "$variable" > "var-notification_channels.auto.tfvars"
