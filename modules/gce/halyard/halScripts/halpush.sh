#!/bin/bash
gsutil -m rsync -d -r /${USER} gs://${BUCKET}

