#!/bin/bash

update_spin(){
    if [ -d /${USER}/x509 ]; then
        if [ -L /${USER}/.spin/config ]; then
            unlink /${USER}/.spin/config
        fi
        ln -s /${USER}/.spin/"$1".config /${USER}/.spin/config
    fi
}

update_kube() {
    if [ -L /${USER}/.kube/config ]; then
        unlink /${USER}/.kube/config
    fi
    ln -s /${USER}/.kube/"$1".config /${USER}/.kube/config
}
