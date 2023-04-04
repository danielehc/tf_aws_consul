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

# ## Check if parameter is populated otherwise exits
# _check_mandatory() {
#   _param="$1"

#   if [ -z "${!_param}" ]; then 
#     _log_err "Mandatory parameter: ${_param} not set."
#     exit 1
#   fi
# }

# ## Check if parameter is populated otherwise warns on usage and assigns default
# _check_optional() {
#   ## Contains the 'name' of the variable to be tested.
#   local -n _param_ref="$1"
#   local _param_value="${!1}"
#   ## Contains the 'value' to be used as default if ${!name} is not set
#   local _default_value="$2"

#   echo "${_param_ref} = ${_param_value} : ${_default_value}"

#   if [ -z "${_param_value}" ]; then 
#     _log_warn "Optional parameter: ${_param_ref} not set...using default"
#     _param_ref=${_default_value}
#   fi
# }

# ++-----------------+
# || Parameters      |
# ++-----------------+

## Check parameters configuration
## This section can be used to introduce failure checks in case a variable is 
## not set properly. It looks a bit ugly to repeat the variables but it might be
## come out handy in future developments.

## Control plane variables
CONSUL_DATACENTER=${CONSUL_DATACENTER:-"dc1"}
CONSUL_DOMAIN=${CONSUL_DOMAIN:-"consul"}
CONSUL_SERVER_NUMBER=${CONSUL_SERVER_NUMBER:-1}

CONSUL_DNS_RECURSOR=${CONSUL_DNS_RECURSOR:-"1.1.1.1"}
CONSUL_DNS_PORT=${CONSUL_DNS_PORT:-"8600"}
CONSUL_HTTPS_PORT=${CONSUL_HTTPS_PORT:-"8443"}

CONSUL_CONFIG_DIR=${CONSUL_CONFIG_DIR:-"/etc/consul.d/"}
CONSUL_DATA_DIR=${CONSUL_DATA_DIR:-"/opt/consul/"}

OUTPUT_FOLDER=${OUTPUT_FOLDER:-"${STEP_ASSETS}"}

CONSUL_GOSSIP_KEY=${CONSUL_GOSSIP_KEY:-""}
CONSUL_LOG_LEVEL=${CONSUL_LOG_LEVEL:-"DEBUG"}

## Check mandatory variables 
[ -z "$CONSUL_RETRY_JOIN" ] && _log_err "Mandatory parameter: ${CONSUL_RETRY_JOIN} not set."  && exit 1
[ -z "$OUTPUT_FOLDER" ]     && _log_err "Mandatory parameter: ${OUTPUT_FOLDER} not set."      && exit 1

# _datacenter=${CONSUL_DATACENTER}
# _domain=${CONSUL_DOMAIN}
# _consul_data_dir=${CONSUL_DATA_DIR}
# _consul_config_dir=${CONSUL_CONFIG_DIR}
# _consul_server_number=${CONSUL_SERVER_NUMBER}


# _dns_recursors=${CONSUL_DNS_RECURSOR}
# _consul_https_port=${CONSUL_HTTPS_PORT}
# _consul_dns_port=${CONSUL_DNS_PORT}

# ## ~todo [CHECK] these ones should be set otherwise configuration is not valid
# _consul_rety_join=${CONSUL_RETRY_JOIN:${RETRY_JOIN}}
# _consul_log_level="DEBUG"
# OUTPUT_FOLDER=${OUTPUT_FOLDER:-${STEP_ASSETS}}

# # ++-----------------+
# # || Variables       |
# # ++-----------------+
# DATACENTER=${_datacenter:-"dc1"}
# DOMAIN=${_domain:-"consul"}
# CONFIG_DIR=${_consul_config_dir:-"/etc/consul.d/"}
# DATA_DIR=${_consul_data_dir:-"/opt/consul/"}
# SERVER_NUMBER=${_consul_server_number:-1}
# JOIN_STRING=${_consul_rety_join}

# DNS_RECURSOR=${_dns_recursors:-"1.1.1.1"}
# HTTPS_PORT=${_consul_https_port:-"8443"}
# DNS_PORT=${_consul_dns_port:-"8600"}

## SECRETS
## Setting these variables from outside the script can inject pre-existing
## secrets into the configuration.
# GOSSIP_KEY="${CONSUL_GOSSIP_KEY}"

# ++-----------------+
# || Begin           |
# ++-----------------+

_header "- Genearate Consul servers configuration"

_log "Cleaning Scenario before apply."
_log_warn "Removing pre-existing configuration in ${OUTPUT_FOLDER}"
rm -rf "${OUTPUT_FOLDER}secrets" && rm -rf "${OUTPUT_FOLDER}consul-server-*"

_log "Generate scenario config folders."

## ~todo [CHECK] check folder existence 
# _log_err "Output: ${OUTPUT_FOLDER}"

mkdir -p "${OUTPUT_FOLDER}" && \
  mkdir -p "${OUTPUT_FOLDER}secrets"

_log "Generate secrets."

pushd "${OUTPUT_FOLDER}secrets"  > /dev/null 2>&1

## Check if using a pre-defined gossip encryption key
if [ ! -z "${CONSUL_GOSSIP_KEY}" ]; then
  _log "Using pre existing encryption key."
else
  _log "Generating Gossip Encryption Key."
  CONSUL_GOSSIP_KEY="$(consul keygen)"
fi

# "Generate gossip encryption key config"
## MARK: [conf] agent-gossip-encryption.hcl
echo "encrypt = \"${CONSUL_GOSSIP_KEY}\"" > ./agent-gossip-encryption.hcl

_log "Generate CA"
## Creates: 
# ${OUTPUT_FOLDER}secrets/consul-agent-ca-key.pem
# ${OUTPUT_FOLDER}secrets/consul-agent-ca.pem
consul tls ca create -domain=${CONSUL_DOMAIN}

_log "Generate Server Certificates"
for i in `seq 0 "$((CONSUL_SERVER_NUMBER-1))"`; do
  consul tls cert create -server -domain=${CONSUL_DOMAIN} -dc=${CONSUL_DATACENTER}
done


popd  > /dev/null 2>&1

## ~todo make all servers discoverable from bastion host
for i in `seq 0 "$((CONSUL_SERVER_NUMBER-1))"`; do
  _log "Generating Configuration for consul-server-$i"

  mkdir -p "${OUTPUT_FOLDER}consul-server-$i"

  # /etc/consul.d/consul-agent-ca.pem
  # /etc/consul.d/consul-agent.pem
  # /etc/consul.d/consul-agent-key.pem

  cp -r ${OUTPUT_FOLDER}secrets/*.hcl "${OUTPUT_FOLDER}consul-server-$i/"
  cp "${OUTPUT_FOLDER}secrets/consul-agent-ca.pem" "${OUTPUT_FOLDER}consul-server-$i/"
  cp "${OUTPUT_FOLDER}secrets/${CONSUL_DATACENTER}-server-${CONSUL_DOMAIN}-$i.pem" "${OUTPUT_FOLDER}consul-server-$i/consul-agent.pem"
  cp "${OUTPUT_FOLDER}secrets/${CONSUL_DATACENTER}-server-${CONSUL_DOMAIN}-$i-key.pem" "${OUTPUT_FOLDER}consul-server-$i/consul-agent-key.pem"
  set +x

  pushd "${OUTPUT_FOLDER}consul-server-$i/"  > /dev/null 2>&1

  # "Generate consul.hcl - requirement for systemd service"
  ## MARK: [conf] consul.hcl
  tee ./consul.hcl > /dev/null << EOF
# -----------------------------+
# consul.hcl                   |
# -----------------------------+

# Node name
node_name = "consul-server-$i"

# Data Persistence
data_dir = "${CONSUL_DATA_DIR}"

# Logging
log_level = "${CONSUL_LOG_LEVEL}"
enable_syslog = true

## Disable script checks
enable_script_checks = false

## Enable local script checks
enable_local_script_checks = true

EOF

  # "Generate server specific configuration"
  ## MARK: [conf] agent-server-specific.hcl
  tee ./agent-server-specific.hcl > /dev/null << EOF
# -----------------------------+
# agent-server-specific.hcl    |
# -----------------------------+

## Server specific configuration for ${CONSUL_DATACENTER}
datacenter = "${CONSUL_DATACENTER}"
domain = "${CONSUL_DOMAIN}"
node_name = "consul-server-$i"
server = true
bootstrap_expect = ${CONSUL_SERVER_NUMBER}

EOF

  # "Generate server specific UI configuration"
  ## MARK: [conf] agent-server-specific-ui.hcl
  tee ./agent-server-specific-ui.hcl > /dev/null << EOF

# -----------------------------+
# agent-server-specific-ui.hcl |
# -----------------------------+

## UI configuration (1.9+)
ui_config {
  enabled = true

  dashboard_url_templates {
    service = "http://${GRAFANA_URI}/d/hashicups/hashicups?orgId=1&var-service={{Service.Name}}"
  }

  metrics_provider = "prometheus"

  metrics_proxy {
    base_url = "http://${PROMETHEUS_URI}/prometheus"
    path_allowlist = ["/api/v1/query_range", "/api/v1/query", "/prometheus/api/v1/query_range", "/prometheus/api/v1/query"]
  }
}
EOF

  ## MARK: [conf] agent-server-networking.hcl
  tee ./agent-server-networking.hcl > /dev/null << EOF
# -----------------------------+
# agent-server-networking.hcl  |
# -----------------------------+

# Enable service mesh
connect {
  enabled = true
}

# Addresses and ports
client_addr = "127.0.0.1"
bind_addr   = "{{ GetInterfaceIP \"eth0\" }}"

addresses {
  grpc = "127.0.0.1"
  http = "127.0.0.1"
  // http = "0.0.0.0"
  https = "0.0.0.0"
  //dns = "127.0.0.1"
  dns = "0.0.0.0"
}

ports {
  http      = 8500
  https     = ${CONSUL_HTTPS_PORT}
  # grpc      = 8502
  grpc_tls  = 8502
  # grpc_tls  = -1
  dns       = ${CONSUL_DNS_PORT}
}

# Join other Consul agents
retry_join = [ "${CONSUL_RETRY_JOIN}" ]

# DNS recursors
recursors = ["${CONSUL_DNS_RECURSORS}"]

EOF

  # "Generate TLS configuration"
  ## MARK: [conf] agent-server-tls.hcl
  tee ./agent-server-tls.hcl > /dev/null << EOF
# -----------------------------+
# agent-server-tls.hcl         |
# -----------------------------+

## TLS Encryption (requires cert files to be present on the server nodes)
tls {
  defaults {
    ca_file   = "${CONSUL_CONFIG_DIR}consul-agent-ca.pem"
    cert_file = "${CONSUL_CONFIG_DIR}consul-agent.pem"
    key_file  = "${CONSUL_CONFIG_DIR}consul-agent-key.pem"
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

# Enable auto-encrypt for server nodes
auto_encrypt {
  allow_tls = true
}
EOF

# "Generate ACL configuration"
## MARK: [conf] agent-server-tls.hcl
tee ./agent-server-acl.hcl > /dev/null << EOF
# -----------------------------+
# agent-server-acl.hcl         |
# -----------------------------+

## ACL configuration
acl = {
  enabled = true
  default_policy = "deny"
  enable_token_persistence = true
  enable_token_replication = true
  down_policy = "extend-cache"
}
EOF

# "Generating Consul agent server telemetry config"
## MARK: [conf] agent-server-telemetry.hcl
tee ./agent-server-telemetry.hcl > /dev/null << EOF
# -----------------------------+
# agent-server-telemetry.hcl   |
# -----------------------------+

telemetry {
  prometheus_retention_time = "60s"
  disable_hostname = true
}
EOF


  ## todo remove before fly
  # cat ./*.hcl

  _log "Validate configuration for consul-server-$i"
  consul validate ./  > /dev/null 2>&1

  STAT=$?

  if [ ${STAT} -ne 0 ];  then
    _log_err "Configuration invalid. Exiting."
    exit 1;
  fi

  popd  > /dev/null 2>&1

done

## todo remove before fly
# tree "${OUTPUT_FOLDER}"

exit 0

