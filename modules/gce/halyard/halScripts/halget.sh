#!/bin/bash
gsutil -m rsync -d -r gs://${BUCKET} /${USER} 
