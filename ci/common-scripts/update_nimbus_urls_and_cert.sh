#!/usr/bin/env bash
set -eu -o pipefail

VCENTER_CA_CERT="$(
  openssl s_client -showcerts -connect "${VCENTER_BASE_URL}:443" 2>/dev/null </dev/null \
  | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p'
)"
echo "${VCENTER_CA_CERT}" > /usr/local/share/ca-certificates/vcenter.crt && update-ca-certificates

# We use an additional dns redirect that will cause TLS to fail
# So we fetch the hostname we're supposed to be using from the Cert
VCENTER_BASE_URL=$(
  openssl x509 -noout -subject -in <(echo "${VCENTER_CA_CERT}") \
  | sed -e 's/^subject.*CN\s*=\s*\([a-zA-Z0-9\.\-]*\).*$/\1/'
)

if [ -n "${VCENTER_ADMIN_CREDENTIAL_URL:-}" ]; then
  VCENTER_ADMIN_CREDENTIAL_URL=$(
    echo "${VCENTER_ADMIN_CREDENTIAL_URL}" \
    | sed "s/\(.*\)vcenter-nimbus.*/\1${VCENTER_BASE_URL}/"
  )
fi

if [ -n "${GOVC_URL:-}" ]; then
  GOVC_URL="$(echo "${GOVC_URL}" | sed "s/\(.*\)vcenter-nimbus.*/\1${VCENTER_BASE_URL}/")"
fi

export VCENTER_CA_CERT
export VCENTER_BASE_URL
export VCENTER_ADMIN_CREDENTIAL_URL
export GOVC_URL
