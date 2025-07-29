#!/usr/bin/env bash
set -eu -o pipefail
set -x

# We have firewall rules that are necessary when creating Windows stemcells in AWS and GCP (if needed).
# This script ensures that the concourse worker egress IPs have access on the
# WinRM port (5985).
# Set firewall rules in the GCP project if needed
if [ "${CONFIGURE_GCP:-}" == "true" ]; then
  comma_separated_external_ips=""
  for external_ip in ${ALLOWED_IP_ADDRESSES}; do
    comma_separated_external_ips="${external_ip}/32,${comma_separated_external_ips}"
  done
  comma_separated_external_ips="${comma_separated_external_ips%,}"

  set +x
  gcp_project_name=$(echo "${WINDOWS_STEMCELLS_GCP_CREDENTIALS_JSON}" | jq -r '.project_id')
  echo "${WINDOWS_STEMCELLS_GCP_CREDENTIALS_JSON}" | gcloud auth activate-service-account --key-file - --project "${gcp_project_name}"
  set -x
  gcloud compute firewall-rules update default-allow-winrm --project "${gcp_project_name}" --source-ranges="${comma_separated_external_ips}"
fi

# Set firewall rules in the AWS project
aws_ip_ranges=""
for external_ip in ${ALLOWED_IP_ADDRESSES}; do
  aws_ip_ranges="{CidrIp=${external_ip}/32},${aws_ip_ranges}"
done
aws_ip_ranges="${aws_ip_ranges%,}"

echo "Set firewall rules in the AWS Commercial project"
if [ -z "${COMMERCIAL_AWS_ROLE_ARN}" ]; then
  set +x
  aws configure --profile commercial set aws_access_key_id "${COMMERCIAL_AWS_ACCESS_KEY_ID}"
  aws configure --profile commercial set aws_secret_access_key "${COMMERCIAL_AWS_SECRET_ACCESS_KEY}"
  set -x
else
  set +x
  aws configure --profile commercial_service_acct set aws_access_key_id "${COMMERCIAL_AWS_ACCESS_KEY_ID}"
  aws configure --profile commercial_service_acct set aws_secret_access_key "${COMMERCIAL_AWS_SECRET_ACCESS_KEY}"
  set -x
  aws configure --profile commercial set source_profile "commercial_service_acct"
  aws configure --profile commercial set role_arn "${COMMERCIAL_AWS_ROLE_ARN}"
fi
aws configure --profile commercial set region "${COMMERCIAL_AWS_DEFAULT_REGION}"

set +e
# This fails if the IP permissions have already been revoked
aws --profile commercial ec2 revoke-security-group-ingress \
  --cli-input-json "$(aws --profile commercial ec2 describe-security-groups | jq -c '.SecurityGroups | map(select(.GroupId == "sg-233e695e"))[0] | {IpPermissions: .IpPermissions, GroupId: .GroupId, GroupName: .GroupName}')"
set -e

aws --profile commercial ec2 authorize-security-group-ingress \
  --group-id sg-233e695e \
  --ip-permissions "FromPort=5985,IpProtocol=tcp,IpRanges=[${aws_ip_ranges}],Ipv6Ranges=[],PrefixListIds=[],ToPort=5985,UserIdGroupPairs=[]"

echo "Set firewall rules in the AWS GovCloud project"
set +x
aws configure --profile govcloud set aws_access_key_id "${GOVCLOUD_AWS_ACCESS_KEY_ID}"
aws configure --profile govcloud set aws_secret_access_key "${GOVCLOUD_AWS_SECRET_ACCESS_KEY}"
set -x
aws configure --profile govcloud set region "${GOVCLOUD_AWS_DEFAULT_REGION}"

set +e
# This fails if the IP permissions have already been revoked
aws --profile govcloud ec2 revoke-security-group-ingress \
  --cli-input-json "$(aws --profile govcloud ec2 describe-security-groups | jq -c '.SecurityGroups | map(select(.GroupId == "sg-1ecb927a"))[0] | {IpPermissions: .IpPermissions, GroupId: .GroupId, GroupName: .GroupName}')"
set -e

aws --profile govcloud ec2 authorize-security-group-ingress \
  --group-id sg-1ecb927a \
  --ip-permissions "FromPort=5985,IpProtocol=tcp,IpRanges=[${aws_ip_ranges}],Ipv6Ranges=[],PrefixListIds=[],ToPort=5985,UserIdGroupPairs=[]"
