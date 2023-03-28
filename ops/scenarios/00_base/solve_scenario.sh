#!/usr/bin/env bash

## Number of servers to spin up (3 or 5 recommended for production environment)
SERVER_NUMBER=1

## Define primary datacenter and domain for the sandbox Consul DC
DOMAIN="consul"
DATACENTER="dc1"

SSH_OPTS="StrictHostKeyChecking=accept-new"

echo "Solving scenario 00"

ASSETS="/home/app/assets"

rm -rf ${ASSETS}

mkdir -p ${ASSETS}

pushd ${ASSETS}

##########################################################
##########################################################

echo "Install Consul"

## Install Consul on operator
cp /opt/bin/consul /usr/local/bin/consul && chmod +x /usr/local/bin/consul

## Install Consul on Consul server
ssh -o ${SSH_OPTS} app@consul${FQDN_SUFFIX} \
      "cp /opt/bin/consul /usr/local/bin/consul && chmod +x /usr/local/bin/consul"

##########################################################
##########################################################

echo "Test Consul installation"

## Local on operator
consul version

## Remote on Consul server
ssh -o ${SSH_OPTS} app@consul${FQDN_SUFFIX} \
      "/usr/local/bin/consul version"

##########################################################
##########################################################

echo "Generate gossip encryption key"

echo encrypt = \"$(consul keygen)\" > agent-gossip-encryption.hcl

##########################################################
##########################################################

echo "Generate CA"

consul tls ca create -domain=${DOMAIN}

##########################################################
##########################################################

echo "Generate Server Certificates"

consul tls cert create -server -domain ${DOMAIN} -dc=${DATACENTER}

##########################################################
##########################################################

echo "Create Consul folders"

ssh -o ${SSH_OPTS} app@consul${FQDN_SUFFIX} \
      "mkdir -p /etc/consul/config && mkdir -p /etc/consul/data"

##########################################################
##########################################################

echo "Generate Configuration"

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

## TLS Encryption (requires cert files to be present on the server nodes)
verify_incoming        = false
verify_incoming_rpc    = true
verify_outgoing        = true
verify_server_hostname = true

auto_encrypt {
  allow_tls = true
}
EOF

# TLS
tee agent-server-tls.hcl > /dev/null << EOF
ca_file   = "/etc/consul/config/consul-agent-ca.pem"
cert_file = "/etc/consul/config/${DATACENTER}-server-${DOMAIN}-0.pem"
key_file  = "/etc/consul/config/${DATACENTER}-server-${DOMAIN}-0-key.pem"
EOF


## ACL

### Consul ACL configuration
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

## Server Specific Connfiguration
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

##########################################################
##########################################################

echo "Copy Configuration on Consul server"

## Copy configuration files
scp -o ${SSH_OPTS} agent-gossip-encryption.hcl                 consul${FQDN_SUFFIX}:/etc/consul/config > /dev/null 2>&1
scp -o ${SSH_OPTS} consul-agent-ca.pem                         consul${FQDN_SUFFIX}:/etc/consul/config > /dev/null 2>&1
scp -o ${SSH_OPTS} ${DATACENTER}-server-${DOMAIN}-0.pem        consul${FQDN_SUFFIX}:/etc/consul/config > /dev/null 2>&1
scp -o ${SSH_OPTS} ${DATACENTER}-server-${DOMAIN}-0-key.pem    consul${FQDN_SUFFIX}:/etc/consul/config > /dev/null 2>&1
scp -o ${SSH_OPTS} agent-server-secure.hcl                     consul${FQDN_SUFFIX}:/etc/consul/config > /dev/null 2>&1
scp -o ${SSH_OPTS} agent-server-tls.hcl                        consul${FQDN_SUFFIX}:/etc/consul/config > /dev/null 2>&1
scp -o ${SSH_OPTS} agent-server-acl.hcl                        consul${FQDN_SUFFIX}:/etc/consul/config > /dev/null 2>&1
scp -o ${SSH_OPTS} agent-server-specific.hcl                   consul${FQDN_SUFFIX}:/etc/consul/config > /dev/null 2>&1

##########################################################
##########################################################

echo "Start Consul"

CONSUL_PID=`ssh -o ${SSH_OPTS} consul${FQDN_SUFFIX} "pidof consul"`

until [ ! -z "${CONSUL_PID}" ] 

do
  ssh -o ${SSH_OPTS} consul${FQDN_SUFFIX} \
    "/usr/local/bin/consul agent \
    -node=consul \
    -log-file=/tmp/consul-server-${DATACENTER} \
    -config-dir=/etc/consul/config > /tmp/consul-server.log 2>&1" &

  sleep 1
  
  CONSUL_PID=`ssh -o StrictHostKeyChecking=accept-new consul "pidof consul"`

done

##########################################################
##########################################################
