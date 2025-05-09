#!/usr/bin/env bash
set -eu -o pipefail
set -x

# We have firewall rules that are necessary when creating Windows stemcells in AWS and GCP.
# This script gets the IPs of our Concourse workers and ensures that they have access on the
# WinRM port (5985).

set +x
echo "${CONCOURSE_GCP_CREDENTIALS_JSON}" | gcloud auth activate-service-account --key-file - --project "${CONCOURSE_GOOGLE_PROJECT_ID}"
set -x
concourse_worker_external_ips=$( \
  gcloud compute instances list \
  --project "${CONCOURSE_GOOGLE_PROJECT_ID}" \
  --filter="labels.instance_group:worker AND networkInterfaces.network:bosh-ecosystem-concourse" \
  --format="value(networkInterfaces[0].accessConfigs[0].natIP)" \
)

if [ -z "${concourse_worker_external_ips}" ]; then
  echo "Unable to find Concourse worker IP addresses"
  exit 1
fi

# Set firewall rules in the GCP project
comma_separated_external_ips=""
for external_ip in $concourse_worker_external_ips; do
  comma_separated_external_ips="${external_ip}/32,${comma_separated_external_ips}"
done
comma_separated_external_ips="${comma_separated_external_ips%,}"

set +x
echo "${WINDOWS_STEMCELLS_GCP_CREDENTIALS_JSON}" | gcloud auth activate-service-account --key-file - --project cff-bosh-windows-stemcells
set -x
gcloud compute firewall-rules update default-allow-winrm --project cff-bosh-windows-stemcells --source-ranges="${comma_separated_external_ips}"

# Set firewall rules in the AWS project
aws_ip_ranges=""
for external_ip in $concourse_worker_external_ips; do
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
