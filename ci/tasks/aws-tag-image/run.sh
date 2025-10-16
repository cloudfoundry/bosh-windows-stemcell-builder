#!/usr/bin/env bash
set -eu -o pipefail

if [ -n "${AWS_ROLE_ARN}" ]; then
  aws configure --profile creds_account set aws_access_key_id "${AWS_ACCESS_KEY_ID}"
  aws configure --profile creds_account set aws_secret_access_key "${AWS_SECRET_ACCESS_KEY}"
  aws configure --profile resource_account set source_profile "creds_account"
  aws configure --profile resource_account set role_arn "${AWS_ROLE_ARN}"
  unset AWS_ACCESS_KEY_ID
  unset AWS_SECRET_ACCESS_KEY
  export AWS_PROFILE=resource_account
fi

set -x

cd candidate-aws-light-stemcell

tar -xzf ./*.tgz stemcell.MF
AMI_LIST=$(grep ami- stemcell.MF | tr -d ' ')
if [ -n "${GREP_PATTERN}" ]; then
  AMI_LIST=$(echo "${AMI_LIST}" | eval "${GREP_PATTERN}")
fi
OS=$(grep "operating_system" stemcell.MF | cut -f2 -d: | tr -d ' ')
VERSION=$(grep "^version" stemcell.MF | cut -f2 -d: | tr -d ' ' | tr -d "'" | tr -d '"')

for AMI_LINE in ${AMI_LIST}; do
  AMI_REGION=$(echo "${AMI_LINE}" | cut -f1 -d:)
  AMI_ID=$(echo "${AMI_LINE}" | cut -f2 -d:)

  TAGS="[
    { \"Key\": \"published\", \"Value\": \"true\" },
    { \"Key\": \"name\"     , \"Value\": \"${OS}-${VERSION}\" },
    { \"Key\": \"distro\"   , \"Value\": \"${OS}\" },
    { \"Key\": \"version\"  , \"Value\": \"${VERSION}\" }
  ]"

  aws ec2 create-tags --resources "${AMI_ID}" --region "${AMI_REGION}" --tags "${TAGS}"
done
