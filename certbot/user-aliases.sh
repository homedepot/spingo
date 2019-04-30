alias pullcerts="gsutil rsync -d -r gs://${BUCKET}/${USER} /${USER}/${USER}"
alias pushcerts="gsutil rsync -d -r /${USER}/${USER} gs://${BUCKET}/${USER}"
alias showlog="tail -f /tmp/install.log | sed '/^startup complete$/ q'"
