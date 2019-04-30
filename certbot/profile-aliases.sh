alias spingo="sudo -H -u ${USER} -i bash"
alias showlog="tail -f /tmp/install.log | sed '/^startup complete$/ q'"
alias pushcerts="gsutil rsync -d -r /${USER}/${USER} gs://${BUCKET}/${USER}"
alias pullcerts="gsutil rsync -d -r gs://${BUCKET}/${USER} /${USER}/${USER}"
