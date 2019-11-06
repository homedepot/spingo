#!/bin/bash

update_spin(){
    if [ -d /${USER}/x509 ]; then
        if [ -L /home/${USER}/.spin/config ]; then
            unlink /home/${USER}/.spin/config
        fi
        ln -s /home/${USER}/.spin/"$1".config /home/${USER}/.spin/config
    fi
}

update_kube() {
    if [ -L /home/${USER}/.kube/config ]; then
        unlink /home/${USER}/.kube/config
    fi
    ln -s /home/${USER}/.kube/"$1".config /home/${USER}/.kube/config
}
