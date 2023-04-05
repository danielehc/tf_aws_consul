#!/usr/bin/env bash

# ++-----------------+
# || Functions       |
# ++-----------------+
## Prints a line on stdout prepended with date and time
_log() {
  echo -e "\033[1m["$(date +"%Y-%d-%d %H:%M:%S")"][`basename $0`] - ${@}\033[0m"
}

_header() {
  echo -e "\033[1m\033[32m["$(date +"%Y-%d-%d %H:%M:%S")"][`basename $0`] ${@}\033[0m"
  # echo -e "\033[1m\033[32m #### - ${@}\033[0m"
  # DEC_HEAD="\033[1m\033[32m[####] \033[0m\033[1m"
  # _log "${DEC_HEAD}${@}"  
}

_log_err() {
  DEC_ERR="\033[1m\033[31m[ERROR] \033[0m\033[1m"
  _log "${DEC_ERR}${@}"  
}

_log_warn() {
  DEC_WARN="\033[1m\033[33m[WARN] \033[0m\033[1m"
  _log "${DEC_WARN}${@}"  
}


# ++-----------------+
# || Parameters      |
# ++-----------------+

## Check parameters configuration

CONSUL_DATACENTER=${CONSUL_DATACENTER:-"dc1"}
CONSUL_DOMAIN=${CONSUL_DOMAIN:-"consul"}
CONSUL_SERVER_NUMBER=${CONSUL_SERVER_NUMBER:-1}

CONSUL_HTTPS_PORT=${CONSUL_HTTPS_PORT:-"8443"}

OUTPUT_FOLDER=${OUTPUT_FOLDER:-"${STEP_ASSETS}"}

## Check mandatory variables 
[ -z "$CONSUL_HTTP_TOKEN" ] && _log_err "Mandatory parameter: ${CONSUL_HTTP_TOKEN} not set."  && exit 1
[ -z "$OUTPUT_FOLDER" ]     && _log_err "Mandatory parameter: ${OUTPUT_FOLDER} not set."      && exit 1

# ## This section can be used to introduce failure checks in case a variable is 
# ## not set properly. It looks a bit ugly to repeat the variables but it might be
# ## come out handy in future developments.
# _datacenter=${CONSUL_DATACENTER}
# _domain=${CONSUL_DOMAIN}
# _consul_server_number=${CONSUL_SERVER_NUMBER}
# # _consul_data_dir=${CONSUL_DATA_DIR}
# # _consul_config_dir=${CONSUL_CONFIG_DIR}


# ## ~todo [CHECK] these ones should be set otherwise configuration is not valid
# OUTPUT_FOLDER=${OUTPUT_FOLDER:-${STEP_ASSETS}}
# _consul_token=${CONSUL_HTTP_TOKEN}

# # ++-----------------+
# # || Variables       |
# # ++-----------------+
# DATACENTER=${_datacenter:-"dc1"}
# DOMAIN=${_domain:-"consul"}
# SERVER_NUMBER=${_consul_server_number:-1}
# TOKEN=${_consul_token}
# # CONFIG_DIR=${_consul_config_dir:-"/etc/consul.d/"}
# # DATA_DIR=${_consul_data_dir:-"/opt/consul/"}
# # JOIN_STRING=${_consul_rety_join}

# # DNS_RECURSOR=${_dns_recursors:-"1.1.1.1"}
# HTTPS_PORT=${_consul_https_port:-"8443"}
# # DNS_PORT=${_consul_dns_port:-"8600"}

## SECRETS
## Setting these variables from outside the script can inject pre-existing
## secrets into the configuration.
# GOSSIP_KEY="${CONSUL_GOSSIP_KEY}"

# ++-----------------+
# || Begin           |
# ++-----------------+

_header "- Generate Consul server tokens"

_log "Cleaning Scenario before apply."
## todo Clean files 
## (at this point cleaning is made by previous scripts but might make sense locally)

_log "Create policies"
tee ${OUTPUT_FOLDER}acl-policy-dns.hcl > /dev/null << EOF
# -----------------------------+
# acl-policy-dns.hcl           |
# -----------------------------+

node_prefix "" {
  policy = "read"
}
service_prefix "" {
  policy = "read"
}
# only needed if using prepared queries
query_prefix "" {
  policy = "read"
}
EOF

tee ${OUTPUT_FOLDER}acl-policy-server-node.hcl > /dev/null << EOF
# -----------------------------+
# acl-policy-server-node.hcl   |
# -----------------------------+

node_prefix "consul-server" {
  policy = "write"
}
EOF

_log "Setting environment variables to communicate with Consul"

export CONSUL_HTTP_ADDR="https://consul-server-0${FQDN_SUFFIX}:${CONSUL_HTTPS_PORT}"
export CONSUL_HTTP_SSL=true
export CONSUL_CACERT="${OUTPUT_FOLDER}secrets/consul-agent-ca.pem"
export CONSUL_TLS_SERVER_NAME="server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}"
export CONSUL_HTTP_TOKEN=${CONSUL_HTTP_TOKEN}

consul acl policy create -name 'acl-policy-dns' -description 'Policy for DNS endpoints' -rules @${OUTPUT_FOLDER}acl-policy-dns.hcl  > /dev/null 2>&1
consul acl policy create -name 'acl-policy-server-node' -description 'Policy for Server nodes' -rules @${OUTPUT_FOLDER}acl-policy-server-node.hcl  > /dev/null 2>&1

consul acl token create -description 'DNS - Default token' -policy-name acl-policy-dns --format json > ${OUTPUT_FOLDER}secrets/acl-token-dns.json 2> /dev/null

DNS_TOK=`cat ${OUTPUT_FOLDER}secrets/acl-token-dns.json | jq -r ".SecretID"` 

_log "Generate server tokens"
for i in `seq 0 "$((CONSUL_SERVER_NUMBER-1))"`; do
  
  export CONSUL_HTTP_ADDR="https://consul-server-$i:${CONSUL_HTTPS_PORT}"
  
  pushd "${OUTPUT_FOLDER}secrets"  > /dev/null 2>&1

  consul acl token create -description "consul-server-$i" -policy-name acl-policy-server-node  --format json > ./consul-server-$i-acl-token.json 2> /dev/null

  SERV_TOK=`cat ./consul-server-$i-acl-token.json | jq -r ".SecretID"`

  consul acl set-agent-token agent ${SERV_TOK}
  consul acl set-agent-token default ${DNS_TOK}

  popd > /dev/null 2>&1

done

