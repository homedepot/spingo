#!/bin/bash

# set target directory where the bucket will sync locally and where the local kubeconfig file will live
# these two things are necessary to volume-mount into the docker container
HAL_RUN_DIR=~/tmp

# google cloud project to use
PROJECT="np-platforms-cd-thd"

# service account name to use
SERVICE_ACCOUNT="spinnaker-us-east1"

# bucket to use
BUCKET="$PROJECT-halyard-bucket"

# base64 operates differently in OSX vs linux
if [[ "$OSTYPE" == "darwin"* ]] && [[ ! -f /usr/local/bin/base64 ]]; then
    BASE64_DECODE="-D"
else
    BASE64_DECODE="-d"
fi

ABORT=0
if [[ ! $(which gsutil) ]] || [[ ! $(which gcloud) ]]; then
    echo "gcloud or gsutil is not installed, cannot proceed. see THD AppStore to install google cloud platform SDK"
    ABORT=1
fi
if [[ ! $(which docker) ]]; then
    echo "docker is not installed, cannot proceed. see THD AppStore to install docker"
    ABORT=1
fi
if [[ ! $(which kubectl) ]]; then
    echo "kubectl is not installed, cannot proceed. see https://kubernetes.io/docs/tasks/tools/install-kubectl/ install kubectl"
    ABORT=1
fi
if [[ "$ABORT" != 0 ]]; then
    exit 1
else
    echo "putting all files into ${HAL_RUN_DIR}"
    if [[ ! -d "${HAL_RUN_DIR}"/spinnaker ]]; then
        mkdir -p "${HAL_RUN_DIR}"/spinnaker
    fi
    echo "pulling google cloud bucket to local directory: ${HAL_RUN_DIR}/spinnaker"
    echo "after making changes to the hal config, you can 'push' local changes back to the bucket by running"
    echo -e "gsutil -m rsync -d -r ${HAL_RUN_DIR}/spinnaker gs://${BUCKET}\n"
    gsutil -m rsync -d -r gs://"${BUCKET}" "${HAL_RUN_DIR}"/spinnaker

    if [[ "$?" != 0 ]]; then
        echo "something went wrong, not proceeding!"
        exit 1
    fi

    export KUBECONFIG="${HAL_RUN_DIR}"/.kube_spinnaker/config
    if [[ ! -f "${HAL_RUN_DIR}"/.kube_spinnaker/config ]]; then
        echo "spinnaker cluster kubectl config file does not exist, creating it now"
        mkdir -p "${HAL_RUN_DIR}"/.kube_spinnaker
        gcloud beta container clusters get-credentials "$SERVICE_ACCOUNT" --region us-east1 --project "$PROJECT"
        kubectl config set-credentials spin_cluster_account --token=$(kubectl get secret $(kubectl get secret --namespace=kube-system | grep default-token | awk '{print $1}') --namespace=kube-system -o jsonpath={.data.token} | base64 ${BASE64_DECODE})
        kubectl config set-context $(kubectl config current-context) --user=spin_cluster_account
    fi

    if [ ! "$(docker ps -q -f name=halyard)" ]; then
        if [ "$(docker ps -aq -f status=exited -f name=halyard)" ]; then
            echo -e "\nremoving old halyard image"
            docker rm halyard
        fi
        echo -e "\nstarting docker container named 'halyard'"
        docker run -p 8084:8084 -p 9000:9000 \
            -d --rm --name halyard \
            -v "${HAL_RUN_DIR}"/spinnaker:/spinnaker \
            -v "${HAL_RUN_DIR}"/spinnaker/.hal:/home/spinnaker/.hal \
            -v "${HAL_RUN_DIR}"/.kube_spinnaker:/home/spinnaker/.kube \
            gcr.io/spinnaker-marketplace/halyard:stable && \
            echo -e "\n\nIt may take about a minute for the halyard daemon to fully start. interact with the container by running:\ndocker exec -ti halyard bash"
    else
        echo -e "\n\nhalyard container already running; interact with the container by running:\ndocker exec -ti halyard bash"
    fi
fi