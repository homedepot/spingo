#!/bin/bash
gsutil -m rsync -d -r -n /${USER} gs://${BUCKET}
