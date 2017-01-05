#!/bin/bash

ACCOUNT_EMAIL=$(echo $ACCOUNT_JSON | jq -r .client_email)
PROJECT_ID=$(echo $ACCOUNT_JSON | jq -r .project_id)

gcloud auth activate-service-account --quiet $ACCOUNT_EMAIL --key-file <(echo $ACCOUNT_JSON)

mkdir -p /root/.ssh
gcloud compute ssh --quiet bosh-bastion \
  --zone=us-east1-d --project=$PROJECT_ID \
  -- -f -N -L 25555:$DIRECTOR_IP:25555

export DIRECTOR_IP=localhost
