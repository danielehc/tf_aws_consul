#!/usr/bin/env bash

# ++-----------------+
# || Variables       |
# ++-----------------+

## Number of servers to spin up (3 or 5 recommended for production environment)
SERVER_NUMBER=1

## Define primary datacenter and domain for the sandbox Consul DC
DOMAIN="consul"
DATACENTER="dc1"

SSH_OPTS="StrictHostKeyChecking=accept-new"

# echo "Solving scenario 00"

ASSETS="/home/app/assets"

rm -rf ${ASSETS}

mkdir -p ${ASSETS}

pushd ${ASSETS}


# ++-----------------+
# || Begin           |
# ++-----------------+


header1 "Starting Consul server"

##########################################################

header2 "Install Consul"

log  "Install Consul on operator"
cp /opt/bin/consul /usr/local/bin/consul && chmod +x /usr/local/bin/consul

log "Test Consul installation"
consul version


header2 Install Consul on Consul server
ssh -o ${SSH_OPTS} app@consul${FQDN_SUFFIX} \
      "cp /opt/bin/consul /usr/local/bin/consul && chmod +x /usr/local/bin/consul"

log "Test Consul installation"
ssh -o ${SSH_OPTS} app@consul${FQDN_SUFFIX} \
      "/usr/local/bin/consul version"

##########################################################
header2 "Create secrets"

log "Generate gossip encryption key"
echo encrypt = \"$(consul keygen)\" > agent-gossip-encryption.hcl

log "Generate CA"
consul tls ca create -domain=${DOMAIN}

log "Generate Server Certificates"
consul tls cert create -server -domain ${DOMAIN} -dc=${DATACENTER}

log "Create Consul folders"

ssh -o ${SSH_OPTS} app@consul${FQDN_SUFFIX} \
      "mkdir -p /etc/consul/config && mkdir -p /etc/consul/data"


##########################################################
header2 "Configure Consul"

log "Generate agent configuration"
tee agent-server-secure.hcl > /dev/null << EOF
# Enable DEBUG logging
log_level = "DEBUG"

# Addresses and ports
addresses {
  grpc = "127.0.0.1"
  // http = "127.0.0.1"
  // http = "0.0.0.0"
  https = "0.0.0.0"
  dns = "127.0.0.1"
}

ports {
  grpc  = 8502
  http  = 8500
  https = 443
  dns   = 53
}

# DNS recursors
recursors = ["1.1.1.1"]

## Disable script checks
enable_script_checks = false

## Enable local script checks
enable_local_script_checks = true

## Data Persistence
data_dir = "/etc/consul/data"

# ## TLS Encryption (requires cert files to be present on the server nodes)
# verify_incoming        = false
# verify_incoming_rpc    = true
# verify_outgoing        = true
# verify_server_hostname = true

# auto_encrypt {
#   allow_tls = true
# }
EOF

log "Generate tls configuration"
tee agent-server-tls.hcl > /dev/null << EOF
## TLS Encryption (requires cert files to be present on the server nodes)
tls {
  defaults {
    ca_file   = "/etc/consul/config/consul-agent-ca.pem"
    cert_file = "/etc/consul/config/${DATACENTER}-server-${DOMAIN}-0.pem"
    key_file  = "/etc/consul/config/${DATACENTER}-server-${DOMAIN}-0-key.pem"

    verify_outgoing        = true
    verify_incoming        = true
  }
  https {
    verify_incoming        = false
  }
  internal_rpc {
    verify_server_hostname = true
  }
}

auto_encrypt {
  allow_tls = true
}
EOF


log "Generate ACL configuration"
tee agent-server-acl.hcl > /dev/null << EOF
## ACL configuration
acl = {
  enabled = true
  default_policy = "deny"
  enable_token_persistence = true
  enable_token_replication = true
  down_policy = "extend-cache"
}
EOF

log "Generate server specific configuration"
tee agent-server-specific.hcl > /dev/null << EOF
## Server specific configuration for ${DATACENTER}
server = true
bootstrap_expect = ${SERVER_NUMBER}
datacenter = "${DATACENTER}"

client_addr = "127.0.0.1"

## UI configuration (1.9+)
ui_config {
  enabled = true
}
EOF

log "Copy Configuration on Consul server"
scp -o ${SSH_OPTS} agent-gossip-encryption.hcl                 consul${FQDN_SUFFIX}:/etc/consul/config > /dev/null 2>&1
scp -o ${SSH_OPTS} consul-agent-ca.pem                         consul${FQDN_SUFFIX}:/etc/consul/config > /dev/null 2>&1
scp -o ${SSH_OPTS} ${DATACENTER}-server-${DOMAIN}-0.pem        consul${FQDN_SUFFIX}:/etc/consul/config > /dev/null 2>&1
scp -o ${SSH_OPTS} ${DATACENTER}-server-${DOMAIN}-0-key.pem    consul${FQDN_SUFFIX}:/etc/consul/config > /dev/null 2>&1
scp -o ${SSH_OPTS} agent-server-secure.hcl                     consul${FQDN_SUFFIX}:/etc/consul/config > /dev/null 2>&1
scp -o ${SSH_OPTS} agent-server-tls.hcl                        consul${FQDN_SUFFIX}:/etc/consul/config > /dev/null 2>&1
scp -o ${SSH_OPTS} agent-server-acl.hcl                        consul${FQDN_SUFFIX}:/etc/consul/config > /dev/null 2>&1
scp -o ${SSH_OPTS} agent-server-specific.hcl                   consul${FQDN_SUFFIX}:/etc/consul/config > /dev/null 2>&1

popd

##########################################################
header2 "Start Consul"

log "Start Consul on Consul server"

set -x

CONSUL_PID=`ssh -o ${SSH_OPTS} consul${FQDN_SUFFIX} "pidof consul"`

until [ ! -z "${CONSUL_PID}" ] 

do
  echo starting attempt

  ssh -o ${SSH_OPTS} consul${FQDN_SUFFIX} \
    "/usr/local/bin/consul agent \
    -node=consul \
    -log-file=/tmp/consul-server-${DATACENTER} \
    -config-dir=/etc/consul/config > /tmp/consul-server.log 2>&1" &

  sleep 1
  
  CONSUL_PID=`ssh -o StrictHostKeyChecking=accept-new consul "pidof consul"`

done

set +x

header2 "Configure ACL"

export CONSUL_HTTP_ADDR="https://consul${FQDN_SUFFIX}"
export CONSUL_HTTP_SSL=true
export CONSUL_CACERT="${ASSETS}/consul-agent-ca.pem"
export CONSUL_TLS_SERVER_NAME="server.${PRIMARY_DATACENTER}.${DOMAIN}"
export CONSUL_FQDN_ADDR="consul${FQDN_SUFFIX}"

log "ACL Bootstrap"

for i in `seq 1 9`; do

  consul acl bootstrap --format json > ${ASSETS}/acl-token-bootstrap.json 2> /dev/null;

  excode=$?

  if [ ${excode} -eq 0 ]; then
    break;
  else
    if [ $i -eq 9 ]; then
      echo -e '\033[1m\033[31m[ERROR] \033[0m Failed to bootstrap ACL system, exiting.';
      exit 1
    else
      echo -e '\033[1m\033[33m[WARN] \033[0m ACL system not ready. Retrying...';
      sleep 5;
    fi
  fi

done

export CONSUL_HTTP_TOKEN=`cat ${ASSETS}/acl-token-bootstrap.json | jq -r ".SecretID"`

# echo $CONSUL_HTTP_TOKEN

log "Create ACL policies and tokens"

tee ${ASSETS}/acl-policy-dns.hcl > /dev/null << EOF
## dns-request-policy.hcl
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

tee ${ASSETS}/acl-policy-server-node.hcl > /dev/null << EOF
## consul-server-one-policy.hcl
node_prefix "consul" {
  policy = "write"
}
EOF

consul acl policy create -name 'acl-policy-dns' -description 'Policy for DNS endpoints' -rules @${ASSETS}/acl-policy-dns.hcl  > /dev/null 2>&1

consul acl policy create -name 'acl-policy-server-node' -description 'Policy for Server nodes' -rules @${ASSETS}/acl-policy-server-node.hcl  > /dev/null 2>&1

consul acl token create -description 'DNS - Default token' -policy-name acl-policy-dns --format json > ${ASSETS}/acl-token-dns.json 2> /dev/null

DNS_TOK=`cat ${ASSETS}/acl-token-dns.json | jq -r ".SecretID"` 

## Create one agent token per server
log "Setup ACL tokens for Server"

consul acl token create -description "server agent token" -policy-name acl-policy-server-node  --format json > ${ASSETS}/server-acl-token.json 2> /dev/null

SERV_TOK=`cat ${ASSETS}/server-acl-token.json | jq -r ".SecretID"`

consul acl set-agent-token agent ${SERV_TOK}
consul acl set-agent-token default ${DNS_TOK}
