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
# || Variables       |
# ++-----------------+
OUTPUT_FOLDER=${OUTPUT_FOLDER:-"${STEP_ASSETS}"}

# ++-----------------+
# || Begin           |
# ++-----------------+

_header "- [${NODE_NAME}]"

_log "Parameter Check"

CONSUL_DATACENTER=${CONSUL_DATACENTER:-"dc1"}
CONSUL_DOMAIN=${CONSUL_DOMAIN:-"consul"}
CONSUL_DATA_DIR=${CONSUL_DATA_DIR:-"/opt/consul/"}
CONSUL_LOG_LEVEL=${CONSUL_LOG_LEVEL:-"DEBUG"}

[ -z "$OUTPUT_FOLDER" ]     && _log_err "Mandatory parameter: OUTPUT_FOLDER not set."      && exit 1
[ -z "$NODE_NAME" ]         && _log_err "Mandatory parameter: NODE_NAME not set."          && exit 1
# [ -z "$CONSUL_GOSSIP_KEY" ] && _log_err "Mandatory parameter: CONSUL_GOSSIP_KEY not set."  && exit 1


_log "Cleaning Scenario before apply."
_log_warn "Removing pre-existing configuration in ${OUTPUT_FOLDER}"
rm -rf "${OUTPUT_FOLDER}${NODE_NAME}"

_log "Generate folder structure"

mkdir -p "${OUTPUT_FOLDER}${NODE_NAME}"

_log "Copy available configuration"

cp -r ${OUTPUT_FOLDER}secrets/*.hcl "${OUTPUT_FOLDER}${NODE_NAME}/"
cp "${OUTPUT_FOLDER}secrets/consul-agent-ca.pem" "${OUTPUT_FOLDER}${NODE_NAME}/"

_log "Generating configuration for Consul agent ${NODE_NAME}"

tee ${OUTPUT_FOLDER}${NODE_NAME}/consul.hcl > /dev/null << EOF
# -----------------------------+
# consul.hcl                   |
# -----------------------------+

server = false
datacenter = "${CONSUL_DATACENTER}"
domain = "${CONSUL_DOMAIN}" 
node_name = "${NODE_NAME}"

# Logging
log_level = "${CONSUL_LOG_LEVEL}"
enable_syslog = true

# Data persistence
data_dir = "${CONSUL_DATA_DIR}"

## Networking 
client_addr = "127.0.0.1"
bind_addr   = "{{ GetInterfaceIP \"eth0\" }}"

# Join other Consul agents
retry_join = [ "${CONSUL_JOIN_STRING}" ]

# Ports
ports {
  http      = 8500
  https     = -1
  # https   = 443
  # grpc      = 8502
  # grpc_tls  = -1
  grpc_tls  = 8502
  dns       = 8600
}

# Enable Consul service mesh
connect {
  enabled = true
}

## Disable script checks
enable_script_checks = false
## Enable local script checks
enable_local_script_checks = true
# Enable central service config
enable_central_service_config = true

## TLS Encryption
tls {
  defaults {
    ca_file   = "/etc/consul.d/consul-agent-ca.pem"
    verify_outgoing        = true
    verify_incoming        = true
  }
  https {
    verify_incoming        = false
  }
  internal_rpc {
    verify_server_hostname = true
  }
  grpc {
    use_auto_cert = true
  }
}

auto_encrypt {
  tls = true
}

## ACL
acl {
  enabled        = true
  default_policy = "deny"
  enable_token_persistence = true
}
EOF

exit 0


