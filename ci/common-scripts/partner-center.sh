#!/usr/bin/env bash
# Shared helpers for the Microsoft Partner Center Product Ingestion API (Graph).
# Requires PARTNER_PORTAL_TENANT_ID, PARTNER_PORTAL_CLIENT_ID and PARTNER_PORTAL_CLIENT_SECRET.
# API bodies are returned raw (configure must resend existing SAS URIs unchanged); anything
# printed to stderr goes through pc_redact_sas, and callers must redact before saving.
# Call pc_token once up front: functions used in $(...) cannot cache a token for the caller.

PC_API="https://graph.microsoft.com/rp/product-ingestion"
PC_TOKEN=""
PC_TOKEN_FETCHED_AT=0
PC_POLL_FIRST_FAILURE=""
# Seconds before a retried request (token, GET) gives up, so a hung connection is retried.
PC_CURL_MAX_TIME=120

# Replaces SAS signatures with sig=REDACTED, and URL-encoded ones (sig%3D, up to the next
# %26) with sig%3DREDACTED (stdin -> stdout).
function pc_redact_sas() {
  sed -E -e "s/sig=[^&\"\\\\' <]*/sig=REDACTED/g" \
    -e "s/sig(%3[dD])([^&%\"\\\\' <]|%[^2&\"\\\\' <]|%2[^6&\"\\\\' <])*/sig\\1REDACTED/g"
}

# True for HTTP codes worth retrying: network error (000), 429 and 5xx.
function _pc_retryable() {
  [[ "${1}" == 000 || "${1}" == 429 || "${1}" == 5* ]]
}

# Fetches a client-credentials token into PC_TOKEN. The secret goes to curl on stdin and
# the token is never written to disk.
function pc_token() {
  local attempt response code rc
  for attempt in 1 2 3 4; do
    if response=$(printf '%s' "${PARTNER_PORTAL_CLIENT_SECRET}" | curl -sS --max-time "${PC_CURL_MAX_TIME}" -w '\n%{http_code}' \
        --data-urlencode "client_id=${PARTNER_PORTAL_CLIENT_ID}" \
        --data-urlencode "client_secret@-" \
        --data-urlencode "grant_type=client_credentials" \
        --data-urlencode "scope=https://graph.microsoft.com/.default" \
        "https://login.microsoftonline.com/${PARTNER_PORTAL_TENANT_ID}/oauth2/v2.0/token"); then
      rc=0
    else
      rc=$?
    fi
    code=${response##*$'\n'}
    response=${response%"${code}"}
    if [[ ${rc} -eq 0 && "${code}" == 2* ]]; then
      if ! PC_TOKEN=$(jq -er .access_token <<<"${response}"); then
        echo "ERROR: token response has no access_token" >&2
        return 1
      fi
      PC_TOKEN_FETCHED_AT=$(date +%s)
      return 0
    fi
    echo "ERROR: token request failed (curl exit ${rc}, HTTP ${code}): $(pc_redact_sas <<<"${response}")" >&2
    if [[ ${rc} -eq 0 ]] && ! _pc_retryable "${code}"; then
      return 1
    fi
    [[ ${attempt} -eq 4 ]] || sleep 30
  done
  return 1
}

# Fetches a token if there is none or it is older than 50 minutes (tokens last 60).
function _pc_ensure_token() {
  if [[ -z "${PC_TOKEN}" || $(( $(date +%s) - PC_TOKEN_FETCHED_AT )) -ge 3000 ]]; then
    pc_token
  fi
}

# pc_get <path> <version>: GET against the API; prints the raw body. Retries network errors,
# 429 and 5xx three times, 30s apart; any other non-2xx fails immediately.
function pc_get() {
  local path="${1}" version="${2}" url attempt body code rc
  url="${PC_API}/${path}"
  if [[ "${url}" == *\?* ]]; then url+="&\$version=${version}"; else url+="?\$version=${version}"; fi
  for attempt in 1 2 3 4; do
    _pc_ensure_token || return 1
    body=$(mktemp "${TMPDIR:-/tmp}/pc-body.XXXXXX")
    if code=$(curl -sS --max-time "${PC_CURL_MAX_TIME}" -o "${body}" -w '%{http_code}' \
        -H @<(printf 'Authorization: Bearer %s\n' "${PC_TOKEN}") \
        "${url}"); then
      rc=0
    else
      rc=$?
    fi
    if [[ ${rc} -eq 0 && "${code}" == 2* ]]; then
      cat "${body}"
      rm -f "${body}"
      return 0
    fi
    echo "ERROR: GET ${path} failed (curl exit ${rc}, HTTP ${code}): $(pc_redact_sas < "${body}")" >&2
    rm -f "${body}"
    if [[ ${rc} -eq 0 ]] && ! _pc_retryable "${code}"; then
      return 1
    fi
    [[ ${attempt} -eq 4 ]] || sleep 30
  done
  return 1
}

# pc_configure <json>: POSTs a configure request (never retried) and prints its jobId.
# Returns 1 on a definite rejection (4xx) and 2 when the request may have been applied
# (network error, 5xx, or a 2xx without a jobId), so the caller can re-read the submissions
# before failing.
function pc_configure() {
  local payload="${1}" body code rc
  _pc_ensure_token || return 1
  body=$(mktemp "${TMPDIR:-/tmp}/pc-body.XXXXXX")
  # No --max-time: a timeout after Microsoft accepted the POST would leave the outcome unknown.
  if code=$(printf '%s' "${payload}" | curl -sS -o "${body}" -w '%{http_code}' -X POST \
      -H @<(printf 'Authorization: Bearer %s\n' "${PC_TOKEN}") \
      -H "Content-Type: application/json" \
      --data-binary @- \
      "${PC_API}/configure?\$version=2022-03-01-preview2"); then
    rc=0
  else
    rc=$?
  fi
  if [[ ${rc} -eq 0 && "${code}" == 2* ]]; then
    if ! jq -er .jobId "${body}"; then
      echo "ERROR: configure response has no jobId: $(pc_redact_sas < "${body}")" >&2
      rm -f "${body}"
      return 2
    fi
    rm -f "${body}"
    return 0
  fi
  echo "ERROR: POST configure failed (curl exit ${rc}, HTTP ${code}): $(pc_redact_sas < "${body}")" >&2
  rm -f "${body}"
  if [[ ${rc} -ne 0 || "${code}" == 5* ]]; then
    return 2
  fi
  return 1
}

# pc_wait_job <jobId> [<done_fn>]: polls the configure job every 60s for up to 60 minutes until it
# completes; fails with its redacted errors unless jobResult is succeeded. While the job is still
# running, <done_fn> (a function name) is called after each poll, in this shell; if it returns 0,
# the wait ends with success without waiting for the job.
function pc_wait_job() {
  local job_id="${1}" done_fn="${2:-}" deadline status job_status job_result
  deadline=$(( $(date +%s) + 3600 ))
  while true; do
    # Refresh here, in this shell: a refresh inside $(pc_get ...) would not outlive the subshell.
    _pc_ensure_token || return 1
    status=$(pc_get "configure/${job_id}/status" 2022-03-01-preview2) || return 1
    job_status=$(jq -r '.jobStatus // empty' <<<"${status}")
    if [[ "${job_status}" == completed ]]; then
      job_result=$(jq -r '.jobResult // empty' <<<"${status}")
      if [[ "${job_result}" == succeeded ]]; then
        echo "Configure job ${job_id} succeeded"
        return 0
      fi
      echo "ERROR: configure job ${job_id} finished with jobResult '${job_result}':" >&2
      jq -r '(.errors // [])[] | "  \(.code // "-"): \(.message // "-") (resource \(.resourceId // "-"))"' \
        <<<"${status}" | pc_redact_sas >&2
      return 1
    fi
    if [[ -n "${done_fn}" ]] && "${done_fn}"; then
      return 0
    fi
    if [[ $(date +%s) -ge ${deadline} ]]; then
      echo "ERROR: configure job ${job_id} timed out after 60 minutes (jobStatus '${job_status}')" >&2
      return 1
    fi
    echo "Configure job ${job_id} is ${job_status:-unknown}; checking again in 60s"
    sleep 60
  done
}

# pc_product_id <offer>: prints the bare product GUID for an offer's externalID.
function pc_product_id() {
  local offer="${1}" product id
  product=$(pc_get "product?externalID=${offer}" 2022-03-01-preview3) || return 1
  if ! id=$(jq -er '(.value // [])[0].id // empty' <<<"${product}"); then
    echo "ERROR: offer '${offer}' not found (or not visible to this Entra app)" >&2
    return 1
  fi
  echo "${id#product/}"
}

# pc_plan_tech_config <product> <sku> [draft|preview|live]: prints (raw, compact) the
# virtual-machine-plan-technical-configuration of the plan whose externalId is <sku>.
function pc_plan_tech_config() {
  local product="${1#product/}" sku="${2}" target="${3:-draft}" path tree
  path="resource-tree/product/${product}"
  [[ "${target}" == draft ]] || path+="?targetType=${target}"
  tree=$(pc_get "${path}" 2022-03-01-preview5) || return 1
  if ! jq -ce --arg sku "${sku}" '
      (.resources // []) as $r
      | [$r[] | select((."$schema" // "") | test("/schema/plan/")) | select(.identity.externalId == $sku) | .id] as $plans
      | if ($plans | length) != 1 then error("expected exactly one plan with externalId \($sku), found \($plans | length)") else $plans[0] end
      | . as $plan
      | [$r[] | select((."$schema" // "") | test("/schema/virtual-machine-plan-technical-configuration/")) | select(.plan == $plan)]
      | if length != 1 then error("expected exactly one technical configuration for plan \($plan) (SKU \($sku)), found \(length)") else .[0] end
      | if ([.skus[]?.skuId] | index($sku)) == null then error("technical configuration for plan \($plan) does not list SKU \($sku)") else . end
    ' <<<"${tree}"; then
    echo "ERROR: could not resolve SKU '${sku}' to a technical configuration in the ${target} tree" >&2
    return 1
  fi
}

# pc_tech_config_blob_state <tech-config json> <version> <blob>: prints "same" when the
# technical configuration holds <version> with an image matching <blob>, "different" when it
# holds <version> with other images only, and "absent" otherwise. Blob match rule: strip the
# query string, drop the scheme, lowercase the host, compare the path as is.
function pc_tech_config_blob_state() {
  jq -r --arg v "${2}" --arg b "${3}" '
    def norm: sub("\\?.*$"; "") | capture("^[A-Za-z][A-Za-z0-9+.-]*://(?<host>[^/]+)(?<path>/.*)?$")
      | "\(.host | ascii_downcase)\(.path // "")";
    ([$b | norm] | first) as $want
    | [(.vmImageVersions // [])[] | select(.versionNumber == $v)] as $found
    | if ($found | length) == 0 then "absent"
      elif [$found[] | (.vmImages // [])[] | .source.osDisk.uri? // empty | select(norm == $want)] | length > 0 then "same"
      else "different" end' <<<"${1}"
}

# pc_release_submission <product> <sku> <version> <blob>: prints
# {"newest": <newest non-draft submission or null>, "isRelease": true|false}, where isRelease
# means the tree for that submission's state holds <version> with a matching blob.
function pc_release_submission() {
  local product="${1#product/}" sku="${2}" version="${3}" blob="${4}" submissions newest tree tech_config is_release=false
  submissions=$(pc_get "submission/${product}" 2022-03-01-preview2) || return 1
  newest=$(jq -c '[(.value // [])[] | select((.target.targetType? // "draft") != "draft")] | max_by(.created)' <<<"${submissions}")
  tree=$(jq -r '
    if . == null or .result == "failed" then ""
    elif .target.targetType == "preview" then (if .status == "completed" and .result == "succeeded" then "preview" else "draft" end)
    elif .target.targetType == "live" then (if .status == "completed" and .result == "succeeded" then "live" else "preview" end)
    else "" end' <<<"${newest}")
  if [[ -n "${tree}" ]]; then
    tech_config=$(pc_plan_tech_config "${product}" "${sku}" "${tree}") || return 1
    [[ $(pc_tech_config_blob_state "${tech_config}" "${version}" "${blob}") != same ]] || is_release=true
  fi
  jq -cn --argjson newest "${newest}" --argjson isRelease "${is_release}" '{newest: $newest, isRelease: $isRelease}'
}

# Multi-day waits: call after a poll (including its token request) failed after retries.
# Fails once the current run of failures has lasted 60 minutes; otherwise waits 10 minutes
# before the caller's next poll. On failing, prints the caller's PC_POLL_GIVE_UP_HINT, if set,
# as the next step.
function pc_poll_failed() {
  local now
  now=$(date +%s)
  PC_POLL_FIRST_FAILURE=${PC_POLL_FIRST_FAILURE:-${now}}
  if [[ $(( now - PC_POLL_FIRST_FAILURE )) -ge 3600 ]]; then
    echo "ERROR: polls have been failing for $(( (now - PC_POLL_FIRST_FAILURE) / 60 )) minutes; giving up" >&2
    [[ -z "${PC_POLL_GIVE_UP_HINT:-}" ]] || echo "${PC_POLL_GIVE_UP_HINT}" >&2
    return 1
  fi
  echo "Poll failed; retrying in 10 minutes"
  sleep 600
}

# Multi-day waits: call after a successful poll to clear the failure run.
function pc_poll_succeeded() {
  PC_POLL_FIRST_FAILURE=""
}
