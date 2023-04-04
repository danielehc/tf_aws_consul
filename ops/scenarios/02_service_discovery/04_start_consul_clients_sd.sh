#!/usr/bin/env bash

# ++-----------------+
# || Variables       |
# ++-----------------+

export STEP_ASSETS="${ASSETS}scenario/conf/"

export NODES_ARRAY=( "hashicups-db" "hashicups-api" "hashicups-frontend" "hashicups-nginx" )

# ++-----------------+
# || Begin           |
# ++-----------------+

header1 "Starting Consul client agents"

# log "Cleaning previous configfuration assets generated"
# for node in ${NODES_ARRAY[@]}; do
#   rm -rf ${STEP_ASSETS}${node}
# done

##########################################################
header2 "Generate Consul clients configuration"

for node in ${NODES_ARRAY[@]}; do
  export NODE_NAME=${node}
  header3 "Generate Consul client configuration for ${NODE_NAME}"

  ## MARK: [script] generate_consul_client_config.sh
  log "[generate_consul_client_config.sh] - [EXTERNAL SCRIPT]"  
  execute_supporting_script "generate_consul_client_config.sh"

  ## MARK: [script] generate_consul_service_config.sh
  log "[generate_consul_service_config.sh] - [EXTERNAL SCRIPT]"
  execute_supporting_script "generate_consul_service_config.sh"

  log "Generate client tokens"

done

# header3 "[SCRIPT] generate_consul_service_config.sh"
# for service_conf in ${NODES_ARRAY[@]}; do
#   export NODE_NAME=${service_conf}
# done

# header3 "Generate Consul agent tokens"
# for service_conf in ${NODES_ARRAY[@]}; do
#   export NODE_NAME=${service_conf}

# done



##########################################################
header2 "Generate Consul client tokens"


##########################################################
header2 "Copy Consul client configuration"

##########################################################
header2 "Start Consul client agents"

exit 0

##==============================================================================
##==============================================================================
##==============================================================================

## Generate intentions
header1 "Generate intentions"

mkdir -p ${ASSETS}/global

tee ${ASSETS}/global/intention-db.hcl > /dev/null << EOF
Kind = "service-intentions"
Name = "hashicups-db"
Sources = [
  {
    Name   = "hashicups-api"
    Action = "allow"
  }
]
EOF

tee ${ASSETS}/global/intention-db.json > /dev/null << EOF
{
  "Kind": "service-intentions",
  "Name": "hashicups-db",
  "Sources": [
    {
      "Action": "allow",
      "Name": "hashicups-api"
    }
  ]
}
EOF

tee ${ASSETS}/global/intention-api.hcl > /dev/null << EOF
Kind = "service-intentions"
Name = "hashicups-api"
Sources = [
  {
    Name   = "hashicups-frontend"
    Action = "allow"
  },
  {
    Name   = "hashicups-nginx"
    Action = "allow"
  }
]
EOF

tee ${ASSETS}/global/intention-api.json > /dev/null << EOF
{
  "Kind": "service-intentions",
  "Name": "hashicups-api",
  "Sources": [
    {
      "Action": "allow",
      "Name": "hashicups-frontend"
    },
    {
      "Action": "allow",
      "Name": "hashicups-nginx"
    }
  ]
}
EOF


tee ${ASSETS}/global/intention-frontend.hcl > /dev/null << EOF
Kind = "service-intentions"
Name = "hashicups-frontend"
Sources = [
  {
    Name   = "hashicups-nginx"
    Action = "allow"
  }
]
EOF

tee ${ASSETS}/global/intention-frontend.json > /dev/null << EOF
{
  "Kind": "service-intentions",
  "Name": "hashicups-frontend",
  "Sources": [
    {
      "Action": "allow",
      "Name": "hashicups-nginx"
    }
  ]
}
EOF

consul config write ${ASSETS}/global/intention-db.hcl
consul config write ${ASSETS}/global/intention-api.hcl
consul config write ${ASSETS}/global/intention-frontend.hcl

header1 "Install Envoy on Clients"

ssh -o ${SSH_OPTS} app@hashicups-db${FQDN_SUFFIX} "cp /opt/bin/envoy /usr/local/bin/envoy && chmod +x /usr/local/bin/envoy"
ssh -o ${SSH_OPTS} app@hashicups-api${FQDN_SUFFIX} "cp /opt/bin/envoy /usr/local/bin/envoy && chmod +x /usr/local/bin/envoy"
ssh -o ${SSH_OPTS} app@hashicups-frontend${FQDN_SUFFIX} "cp /opt/bin/envoy /usr/local/bin/envoy && chmod +x /usr/local/bin/envoy"
ssh -o ${SSH_OPTS} app@hashicups-nginx${FQDN_SUFFIX} "cp /opt/bin/envoy /usr/local/bin/envoy && chmod +x /usr/local/bin/envoy"


header1 "Starting Consul client agents"

log ""
tee ${ASSETS}/agent-client-secure.hcl > /dev/null << EOF
## agent-client-secure.hcl
server = false
datacenter = "${DATACENTER}"
domain = "${DOMAIN}" 

# Logging
log_level = "TRACE"

#client_addr = "127.0.0.1"

retry_join = [ "${SERVER_NAME}${FQDN_SUFFIX}" ]

# Enable service mesh
connect {
  enabled = true
}

# Ports
ports {
  grpc  = 8502
  http  = 8500
  # https = 443
  https = -1
  dns   = 8600
}

enable_script_checks = false

enable_central_service_config = true

data_dir = "/etc/consul/data"

# ## TLS Encryption (requires cert files to be present on the server nodes)
# tls {
#   defaults {
#     ca_file   = "/etc/consul/config/consul-agent-ca.pem"
#     verify_outgoing        = true
#     verify_incoming        = true
#   }
#   https {
#     verify_incoming        = false
#   }
#   internal_rpc {
#     verify_server_hostname = true
#   }
# }

## TLS encryption OLD
verify_incoming        = false
verify_incoming_rpc    = true
verify_outgoing        = true
verify_server_hostname = true
ca_file = "/etc/consul/config/consul-agent-ca.pem"


auto_encrypt {
  tls = true
}

acl {
  enabled        = true
  default_policy = "deny"
  enable_token_persistence = true
}
EOF

##################
## Database
##################
SERVICE="hashicups-db"
NODE_NAME=${SERVICE}

header2 "Starting agent for ${SERVICE}"

log "Install Consul on ${SERVICE}"
ssh -o ${SSH_OPTS} app@${SERVICE}${FQDN_SUFFIX} \
      "cp /opt/bin/consul /usr/local/bin/consul && chmod +x /usr/local/bin/consul"

# log "Install Envoy on ${SERVICE}"
# ssh -o ${SSH_OPTS} app@${SERVICE}${FQDN_SUFFIX} \
#       "cp /opt/bin/envoy /usr/local/bin/envoy && chmod +x /usr/local/bin/envoy"

log "Create Consul folders"
ssh -o ${SSH_OPTS} app@${SERVICE}${FQDN_SUFFIX} \
      "mkdir -p /etc/consul/config && mkdir -p /etc/consul/data"

log "Create node specific configuration"

# consul acl token create -description "svc-${dc}-${svc} agent token" -node-identity "${ADDR}:${dc}" -service-identity="${svc}"  --format json > ${ASSETS}/acl-token-${ADDR}.json 2> /dev/null
# AGENT_TOK=`cat ${ASSETS}/acl-token-${ADDR}.json | jq -r ".SecretID"`

# Using root token for now
AGENT_TOKEN=`cat ${ASSETS}/acl-token-bootstrap.json | jq -r ".SecretID"`

tee ${ASSETS}/agent-client-${SERVICE}-acl-tokens.hcl > /dev/null << EOF
acl {
  tokens {
    agent  = "${AGENT_TOKEN}"
    default  = "${AGENT_TOKEN}"
  }
}
EOF


log "Create service configuration"

tee ${ASSETS}/svc-${SERVICE}.hcl > /dev/null << EOF
## svc-${SERVICE}.hcl
service {
  name = "${SERVICE}"
  id = "${SERVICE}-1"
  tags = ["v1"]
  port = 5432
  
  connect {
    sidecar_service {}
  }  
  
  check {
    id =  "check-${SERVICE}",
    name = "Product ${SERVICE} status check",
    service_id = "${SERVICE}-1",
    tcp  = "localhost:5432",
    interval = "1s",
    timeout = "1s"
  }
}
EOF

log "Copy configuration files on ${SERVICE}"

scp -o ${SSH_OPTS} ${ASSETS}/agent-gossip-encryption.hcl             ${SERVICE}${FQDN_SUFFIX}:/etc/consul/config/ > /dev/null 2>&1
scp -o ${SSH_OPTS} ${ASSETS}/agent-client-secure.hcl                 ${SERVICE}${FQDN_SUFFIX}:/etc/consul/config/ > /dev/null 2>&1
scp -o ${SSH_OPTS} ${ASSETS}/consul-agent-ca.pem                     ${SERVICE}${FQDN_SUFFIX}:/etc/consul/config/consul-agent-ca.pem > /dev/null 2>&1
scp -o ${SSH_OPTS} ${ASSETS}/agent-client-${SERVICE}-acl-tokens.hcl  ${SERVICE}${FQDN_SUFFIX}:/etc/consul/config/ > /dev/null 2>&1
scp -o ${SSH_OPTS} ${ASSETS}/svc-${SERVICE}.hcl                      ${SERVICE}${FQDN_SUFFIX}:/etc/consul/config/ > /dev/null 2>&1

log "Starting Consul on ${SERVICE}"

CONSUL_PID=`ssh -o ${SSH_OPTS} ${SERVICE}${FQDN_SUFFIX} "pidof consul"`

until [ ! -z "${CONSUL_PID}" ] 

do
  log_warn "Consul not started yet...starting"

  ssh -o ${SSH_OPTS} ${SERVICE}${FQDN_SUFFIX} \
    "/usr/local/bin/consul agent \
    -node=${SERVICE} \
    -log-file=/tmp/consul-agent \
    -config-dir=/etc/consul/config > /tmp/consul-agent.log 2>&1" &

  sleep 1
  
  CONSUL_PID=`ssh -o StrictHostKeyChecking=accept-new ${SERVICE}${FQDN_SUFFIX} "pidof consul"`
done

log "Start sidecar proxy for ${SERVICE}"
TOK=${AGENT_TOKEN}

set -x

ssh -o ${SSH_OPTS} ${SERVICE}${FQDN_SUFFIX} \
  "/usr/local/bin/consul connect envoy -token=${TOK} -envoy-binary /usr/local/bin/envoy -sidecar-for ${SERVICE}-1 -- -l trace > /tmp/sidecar-proxy.log 2>&1 &"

# ssh -o ${SSH_OPTS} ${SERVICE}${FQDN_SUFFIX} \
#   "/usr/local/bin/consul connect envoy -token=${TOK} -envoy-binary /usr/local/bin/envoy -sidecar-for ${SERVICE}-1 -admin-bind ${ENVOY_ADMIN_BIND} -- -l trace > /tmp/sidecar-proxy.log 2>&1 &"

set +x 

##################
## API
##################

SERVICE="hashicups-api"
NODE_NAME=${SERVICE}

header2 "Starting agent for ${SERVICE}"

log "Install Consul on ${SERVICE}"
ssh -o ${SSH_OPTS} app@${SERVICE}${FQDN_SUFFIX} \
      "cp /opt/bin/consul /usr/local/bin/consul && chmod +x /usr/local/bin/consul"

# log "Install Envoy on ${SERVICE}"
# ssh -o ${SSH_OPTS} app@${SERVICE}${FQDN_SUFFIX} \
#       "cp /opt/bin/envoy /usr/local/bin/envoy && chmod +x /usr/local/bin/envoy"

log "Create Consul folders"
ssh -o ${SSH_OPTS} app@${SERVICE}${FQDN_SUFFIX} \
      "mkdir -p /etc/consul/config && mkdir -p /etc/consul/data"

log "Create node specific configuration"

# consul acl token create -description "svc-${dc}-${svc} agent token" -node-identity "${ADDR}:${dc}" -service-identity="${svc}"  --format json > ${ASSETS}/acl-token-${ADDR}.json 2> /dev/null
# AGENT_TOK=`cat ${ASSETS}/acl-token-${ADDR}.json | jq -r ".SecretID"`

# Using root token for now
AGENT_TOKEN=`cat ${ASSETS}/acl-token-bootstrap.json | jq -r ".SecretID"`

tee ${ASSETS}/agent-client-${SERVICE}-acl-tokens.hcl > /dev/null << EOF
acl {
  tokens {
    agent  = "${AGENT_TOKEN}"
    default  = "${AGENT_TOKEN}"
  }
}
EOF

log "Create service configuration"

tee ${ASSETS}/svc-${SERVICE}.hcl > /dev/null << EOF
## svc-${SERVICE}.hcl
service {
  name = "${SERVICE}"
  id = "${SERVICE}-1"
  tags = ["v1"]
  port = 8081
  
  connect {
    sidecar_service {
      proxy {
        upstreams = [
          {
            destination_name = "hashicups-db"
            local_bind_port = 5432
          }
        ]
      }
    }
  }

  checks =[ 
    {
      id =  "check-${SERVICE}",
      name = "Product ${SERVICE} status check",
      service_id = "${SERVICE}-1",
      tcp  = "localhost:8081",
      interval = "1s",
      timeout = "1s"
    },
    {
      id =  "check-${SERVICE}-1",
      name = "Product ${SERVICE} status check 1",
      service_id = "${SERVICE}-1",
      tcp  = "${SERVICE}${FQDN_SUFFIX}:8080",
      interval = "1s",
      timeout = "1s"
    },
    {
      id =  "check-${SERVICE}-2",
      name = "Product ${SERVICE} status check 2",
      service_id = "${SERVICE}-1",
      tcp  = "localhost:9090",
      interval = "1s",
      timeout = "1s"
    }
  ]
}
EOF

log "Copy configuration files on ${SERVICE}"

scp -o ${SSH_OPTS} ${ASSETS}/agent-gossip-encryption.hcl             ${SERVICE}${FQDN_SUFFIX}:/etc/consul/config/ > /dev/null 2>&1
scp -o ${SSH_OPTS} ${ASSETS}/agent-client-secure.hcl                 ${SERVICE}${FQDN_SUFFIX}:/etc/consul/config/ > /dev/null 2>&1
scp -o ${SSH_OPTS} ${ASSETS}/consul-agent-ca.pem                     ${SERVICE}${FQDN_SUFFIX}:/etc/consul/config/consul-agent-ca.pem > /dev/null 2>&1
scp -o ${SSH_OPTS} ${ASSETS}/agent-client-${SERVICE}-acl-tokens.hcl  ${SERVICE}${FQDN_SUFFIX}:/etc/consul/config/ > /dev/null 2>&1
scp -o ${SSH_OPTS} ${ASSETS}/svc-${SERVICE}.hcl                      ${SERVICE}${FQDN_SUFFIX}:/etc/consul/config/ > /dev/null 2>&1

log "Starting Consul on ${SERVICE}"

CONSUL_PID=`ssh -o ${SSH_OPTS} ${SERVICE}${FQDN_SUFFIX} "pidof consul"`

until [ ! -z "${CONSUL_PID}" ] 

do
  log_warn "Consul not started yet...starting"

  ssh -o ${SSH_OPTS} ${SERVICE}${FQDN_SUFFIX} \
    "/usr/local/bin/consul agent \
    -node=${SERVICE} \
    -log-file=/tmp/consul-agent \
    -config-dir=/etc/consul/config > /tmp/consul-agent.log 2>&1" &

  sleep 1
  
  CONSUL_PID=`ssh -o StrictHostKeyChecking=accept-new ${SERVICE}${FQDN_SUFFIX} "pidof consul"`
done

log "Start sidecar proxy for ${SERVICE}"
TOK=${AGENT_TOKEN}

ssh -o ${SSH_OPTS} ${SERVICE}${FQDN_SUFFIX} \
  "/usr/local/bin/consul connect envoy -token=${TOK} -envoy-binary /usr/local/bin/envoy -sidecar-for ${SERVICE}-1 -- -l trace > /tmp/sidecar-proxy.log 2>&1 &"

##################
## Frontend
##################
SERVICE="hashicups-frontend"
NODE_NAME=${SERVICE}

header2 "Starting agent for ${SERVICE}"

log "Install Consul on ${SERVICE}"
ssh -o ${SSH_OPTS} app@${SERVICE}${FQDN_SUFFIX} \
      "cp /opt/bin/consul /usr/local/bin/consul && chmod +x /usr/local/bin/consul"

# log "Install Envoy on ${SERVICE}"
# ssh -o ${SSH_OPTS} app@${SERVICE}${FQDN_SUFFIX} \
#       "cp /opt/bin/envoy /usr/local/bin/envoy && chmod +x /usr/local/bin/envoy"

log "Create Consul folders"
ssh -o ${SSH_OPTS} app@${SERVICE}${FQDN_SUFFIX} \
      "mkdir -p /etc/consul/config && mkdir -p /etc/consul/data"

log "Create node specific configuration"

# consul acl token create -description "svc-${dc}-${svc} agent token" -node-identity "${ADDR}:${dc}" -service-identity="${svc}"  --format json > ${ASSETS}/acl-token-${ADDR}.json 2> /dev/null
# AGENT_TOK=`cat ${ASSETS}/acl-token-${ADDR}.json | jq -r ".SecretID"`

# Using root token for now
AGENT_TOKEN=`cat ${ASSETS}/acl-token-bootstrap.json | jq -r ".SecretID"`

tee ${ASSETS}/agent-client-${SERVICE}-acl-tokens.hcl > /dev/null << EOF
acl {
  tokens {
    agent  = "${AGENT_TOKEN}"
    default  = "${AGENT_TOKEN}"
  }
}
EOF


log "Create service configuration"

tee ${ASSETS}/svc-${SERVICE}.hcl > /dev/null << EOF
## svc-${SERVICE}.hcl
service {
  name = "${SERVICE}"
  id = "${SERVICE}-1"
  tags = ["v1"]
  port = 3000
  
  connect {
    sidecar_service {
      proxy {
        upstreams {
            destination_name = "hashicups-api"
            local_bind_address = "127.0.0.1"
            local_bind_port = 8081
        }
      }
    }
  }

  check {
    id =  "check-${SERVICE}",
    name = "Product ${SERVICE} status check",
    service_id = "${SERVICE}-1",
    tcp  = "localhost:3000",
    interval = "1s",
    timeout = "1s"
  }
}
EOF

# tee ${ASSETS}/svc-${SERVICE}.hcl > /dev/null << EOF
# ## svc-${SERVICE}.hcl
# service {
#   name = "${SERVICE}"
#   id = "${SERVICE}-1"
#   tags = ["v1"]
#   port = 3000
  
#   connect {
#     sidecar_service {
#       proxy {
#         upstreams = [
#           {
#             destination_name = "api"
#             local_bind_port = 8081
#           }
#         ]
#       }
#     }
#   }

#   check {
#     id =  "check-${SERVICE}",
#     name = "Product ${SERVICE} status check",
#     service_id = "${SERVICE}-1",
#     tcp  = "${SERVICE}${FQDN_SUFFIX}:3000",
#     interval = "1s",
#     timeout = "1s"
#   }
# }
# EOF

log "Copy configuration files on ${SERVICE}"

scp -o ${SSH_OPTS} ${ASSETS}/agent-gossip-encryption.hcl             ${SERVICE}${FQDN_SUFFIX}:/etc/consul/config/ > /dev/null 2>&1
scp -o ${SSH_OPTS} ${ASSETS}/agent-client-secure.hcl                 ${SERVICE}${FQDN_SUFFIX}:/etc/consul/config/ > /dev/null 2>&1
scp -o ${SSH_OPTS} ${ASSETS}/consul-agent-ca.pem                     ${SERVICE}${FQDN_SUFFIX}:/etc/consul/config/consul-agent-ca.pem > /dev/null 2>&1
scp -o ${SSH_OPTS} ${ASSETS}/agent-client-${SERVICE}-acl-tokens.hcl  ${SERVICE}${FQDN_SUFFIX}:/etc/consul/config/ > /dev/null 2>&1
scp -o ${SSH_OPTS} ${ASSETS}/svc-${SERVICE}.hcl                      ${SERVICE}${FQDN_SUFFIX}:/etc/consul/config/ > /dev/null 2>&1

log "Starting Consul on ${SERVICE}"

CONSUL_PID=`ssh -o ${SSH_OPTS} ${SERVICE}${FQDN_SUFFIX} "pidof consul"`

until [ ! -z "${CONSUL_PID}" ] 

do
  log_warn "Consul not started yet...starting"

  ssh -o ${SSH_OPTS} ${SERVICE}${FQDN_SUFFIX} \
    "/usr/local/bin/consul agent \
    -node=${SERVICE} \
    -log-file=/tmp/consul-agent \
    -config-dir=/etc/consul/config > /tmp/consul-agent.log 2>&1" &

  sleep 1
  
  CONSUL_PID=`ssh -o StrictHostKeyChecking=accept-new ${SERVICE}${FQDN_SUFFIX} "pidof consul"`
done

log "Start sidecar proxy for ${SERVICE}"
TOK=${AGENT_TOKEN}

set -x

ssh -o ${SSH_OPTS} ${SERVICE}${FQDN_SUFFIX} \
  "/usr/local/bin/consul connect envoy -token=${TOK} -envoy-binary /usr/local/bin/envoy -sidecar-for ${SERVICE}-1 -- -l trace > /tmp/sidecar-proxy.log 2>&1 &"

set +x

##################
## NGINX
##################

SERVICE="hashicups-nginx"
NODE_NAME=${SERVICE}

header2 "Starting agent for ${SERVICE}"

log "Install Consul on ${SERVICE}"
ssh -o ${SSH_OPTS} app@${SERVICE}${FQDN_SUFFIX} \
      "cp /opt/bin/consul /usr/local/bin/consul && chmod +x /usr/local/bin/consul"

# log "Install Envoy on ${SERVICE}"
# ssh -o ${SSH_OPTS} app@${SERVICE}${FQDN_SUFFIX} \
#       "cp /opt/bin/envoy /usr/local/bin/envoy && chmod +x /usr/local/bin/envoy"

log "Create Consul folders"
ssh -o ${SSH_OPTS} app@${SERVICE}${FQDN_SUFFIX} \
      "mkdir -p /etc/consul/config && mkdir -p /etc/consul/data"

log "Create node specific configuration"

# consul acl token create -description "svc-${dc}-${svc} agent token" -node-identity "${ADDR}:${dc}" -service-identity="${svc}"  --format json > ${ASSETS}/acl-token-${ADDR}.json 2> /dev/null
# AGENT_TOK=`cat ${ASSETS}/acl-token-${ADDR}.json | jq -r ".SecretID"`

# Using root token for now
AGENT_TOKEN=`cat ${ASSETS}/acl-token-bootstrap.json | jq -r ".SecretID"`

tee ${ASSETS}/agent-client-${SERVICE}-acl-tokens.hcl > /dev/null << EOF
acl {
  tokens {
    agent  = "${AGENT_TOKEN}"
    default  = "${AGENT_TOKEN}"
  }
}
EOF


log "Create service configuration"

tee ${ASSETS}/svc-${SERVICE}.hcl > /dev/null << EOF
## svc-${SERVICE}.hcl
service {
  name = "${SERVICE}"
  id = "${SERVICE}-1"
  tags = ["v1"]
  port = 80
  
  connect {
    sidecar_service {
      proxy {
        upstreams = [
          {
            destination_name = "hashicups-frontend"
            local_bind_port = 3000
          },
          {
            destination_name = "hashicups-api"
            local_bind_port = 8081
          }
        ]
      }
    }
  }

  check {
    id =  "check-${SERVICE}",
    name = "Product ${SERVICE} status check",
    service_id = "${SERVICE}-1",
    tcp  = "${SERVICE}${FQDN_SUFFIX}:80",
    interval = "1s",
    timeout = "1s"
  }
}
EOF

log "Copy configuration files on ${SERVICE}"

scp -o ${SSH_OPTS} ${ASSETS}/agent-gossip-encryption.hcl             ${SERVICE}${FQDN_SUFFIX}:/etc/consul/config/ > /dev/null 2>&1
scp -o ${SSH_OPTS} ${ASSETS}/agent-client-secure.hcl                 ${SERVICE}${FQDN_SUFFIX}:/etc/consul/config/ > /dev/null 2>&1
scp -o ${SSH_OPTS} ${ASSETS}/consul-agent-ca.pem                     ${SERVICE}${FQDN_SUFFIX}:/etc/consul/config/consul-agent-ca.pem > /dev/null 2>&1
scp -o ${SSH_OPTS} ${ASSETS}/agent-client-${SERVICE}-acl-tokens.hcl  ${SERVICE}${FQDN_SUFFIX}:/etc/consul/config/ > /dev/null 2>&1
scp -o ${SSH_OPTS} ${ASSETS}/svc-${SERVICE}.hcl                      ${SERVICE}${FQDN_SUFFIX}:/etc/consul/config/ > /dev/null 2>&1

log "Starting Consul on ${SERVICE}"

CONSUL_PID=`ssh -o ${SSH_OPTS} ${SERVICE}${FQDN_SUFFIX} "pidof consul"`

until [ ! -z "${CONSUL_PID}" ]
do
  log_warn "Consul not started yet...starting"

  ssh -o ${SSH_OPTS} ${SERVICE}${FQDN_SUFFIX} \
    "/usr/local/bin/consul agent \
    -node=${SERVICE} \
    -log-file=/tmp/consul-agent \
    -config-dir=/etc/consul/config > /tmp/consul-agent.log 2>&1" &

  sleep 1
  
  CONSUL_PID=`ssh -o StrictHostKeyChecking=accept-new ${SERVICE}${FQDN_SUFFIX} "pidof consul"`
done

log "Start sidecar proxy for ${SERVICE}"
TOK=${AGENT_TOKEN}

ssh -o ${SSH_OPTS} ${SERVICE}${FQDN_SUFFIX} \
  "/usr/local/bin/consul connect envoy -token=${TOK} -envoy-binary /usr/local/bin/envoy -sidecar-for ${SERVICE}-1 -- -l trace > /tmp/sidecar-proxy.log 2>&1 &"

## Generate intentions



