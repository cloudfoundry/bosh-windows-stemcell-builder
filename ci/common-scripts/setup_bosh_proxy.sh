function setup_bosh_proxy {
  SSH_TUNNEL_USER=${1}; shift
  SSH_TUNNEL_IP=${1}; shift
  SSH_TUNNEL_PRIVATE_KEY=${1}; shift

  set +x
  key_file=/tmp/bosh_ga.key
  prefix_pattern="-----BEGIN\|-----END\|RSA\|PRIVATE\|PUBLIC"
  echo "${SSH_TUNNEL_PRIVATE_KEY}" \
    | sed -e "s/\(${prefix_pattern}\) /\1\t/g" \
    | sed -e "s/ /\n/g" \
    | sed -e "s/\(${prefix_pattern}\)\t/\1 /g" > "${key_file}"
  chmod 600 "${key_file}"
  export BOSH_GW_PRIVATE_KEY="${key_file}"

  export BOSH_ALL_PROXY="ssh+socks5://${SSH_TUNNEL_USER}@${SSH_TUNNEL_IP}:22?private-key=${key_file}"
}
