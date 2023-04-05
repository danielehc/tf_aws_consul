#!/usr/bin/env bash

# ++-----------------+
# || Variables       |
# ++-----------------+

export STEP_ASSETS="${ASSETS}scenario/conf/"

export NODES_ARRAY=( "hashicups-db" "hashicups-api" "hashicups-frontend" "hashicups-nginx" )

# ++-----------------+
# || Begin           |
# ++-----------------+

header1 "Starting Consul service mesh"


##########################################################
header2 "Generate Consul clients configuration"

for node in ${NODES_ARRAY[@]}; do
  NODE_NAME=${node}
  header3 "Modify service configuration for ${NODE_NAME}"
  
  log "Copy service files into Consul configuration directory"
  remote_exec ${NODE_NAME} "cp ${CONSUL_CONFIG_DIR}svc/service_mesh/*.hcl ${CONSUL_CONFIG_DIR}"

  log "Reload Consul configuration"
  _agent_token=`cat ${STEP_ASSETS}secrets/acl-token-${NODE_NAME}.json | jq -r ".SecretID"`

  log_warn "Agent token: ${_agent_token}"

  remote_exec ${NODE_NAME} "/usr/bin/consul reload -token=${_agent_token}"

done

##########################################################
header2 "Starting Envoy sidecar proxies"

for node in ${NODES_ARRAY[@]}; do
  NODE_NAME=${node}
  header3 "Start Envoy sidecar for ${NODE_NAME}"
  
  _agent_token=`cat ${STEP_ASSETS}secrets/acl-token-${NODE_NAME}.json | jq -r ".SecretID"`
  
  ## !todo Remove before fly. Test with bootstrap token
  _agent_token=${CONSUL_HTTP_TOKEN}

  log "Stop existing instances"
  _ENVOY_PID=`remote_exec ${NODE_NAME} "pidof envoy"`
  if [ ! -z ${_ENVOY_PID} ]; then
    remote_exec ${NODE_NAME} "sudo kill -9 ${_ENVOY_PID}"
  fi

  log "Start new instance"
  remote_exec ${NODE_NAME} "/usr/bin/consul connect envoy \
                              -token=${_agent_token} \
                              -envoy-binary /usr/bin/envoy \
                              -sidecar-for ${NODE_NAME}-1 \
                              ${ENVOY_EXTRA_OPT} -- -l trace > /tmp/sidecar-proxy.log 2>&1 &"
  
done



##########################################################
header2 "Restart Services on local interface"

for node in ${NODES_ARRAY[@]}; do
  NODE_NAME=${node}
  
  if [ "${NODE_NAME}" == "hashicups-nginx" ]; then
    log_warn "Not restarting ${NODE_NAME} to provide access"
  else
    log "Restarting ${NODE_NAME}"
    remote_exec ${NODE_NAME} "bash ~/start_service.sh local" > /dev/null 2>&1
  fi
done





log_err "Consul Token: ${CONSUL_HTTP_TOKEN}"

exit 0





# log "Cleaning previous configfuration assets generated"
# for node in ${NODES_ARRAY[@]}; do
#   rm -rf ${STEP_ASSETS}${node}
# done

##########################################################
header2 "Generate Consul clients configuration"

for node in ${NODES_ARRAY[@]}; do
  export NODE_NAME=${node}
  # export CONSUL_RETRY_JOIN
  header3 "Generate Consul client configuration for ${NODE_NAME}"

  ## MARK: [script] generate_consul_client_config.sh
  log "[EXTERNAL SCRIPT] - Generate Consul config"  
  execute_supporting_script "generate_consul_client_config.sh"

  ## MARK: [script] generate_consul_service_config.sh
  ## -todo move service definition map outside
  log "[EXTERNAL SCRIPT] - Generate services config"
  execute_supporting_script "generate_consul_service_config.sh"

  ## This step is Service Discovery so we copy the relevant service definition 
  ## into Consul configuration
  cp ${STEP_ASSETS}${NODE_NAME}/svc/service_discovery/*.hcl "${STEP_ASSETS}${NODE_NAME}"

  log "Generate client tokens"

  tee ${STEP_ASSETS}acl-policy-${NODE_NAME}.hcl > /dev/null << EOF
# Allow the service and its sidecar proxy to register into the catalog.
service "${NODE_NAME}" {
    policy = "write"
}

service "${NODE_NAME}-sidecar-proxy" {
    policy = "write"
}

node_prefix "" {
    policy = "read"
}

# Allow the agent to register its own node in the Catalog and update its network coordinates
node "${NODE_NAME}" {
  policy = "write"
}

# Allows the agent to detect and diff services registered to itself. This is used during
# anti-entropy to reconcile difference between the agents knowledge of registered
# services and checks in comparison with what is known in the Catalog.
service_prefix "" {
  policy = "read"
}
EOF

  consul acl policy create -name "acl-policy-${NODE_NAME}" -description 'Policy for service node' -rules @${STEP_ASSETS}acl-policy-${NODE_NAME}.hcl  > /dev/null 2>&1

  consul acl token create -description "${NODE_NAME} - Default token" -policy-name acl-policy-${NODE_NAME} --format json > ${STEP_ASSETS}secrets/acl-token-${NODE_NAME}.json 2> /dev/null

  DNS_TOK=`cat ${STEP_ASSETS}secrets/acl-token-dns.json | jq -r ".SecretID"`
  AGENT_TOKEN=`cat ${STEP_ASSETS}secrets/acl-token-${NODE_NAME}.json | jq -r ".SecretID"` 

  tee ${STEP_ASSETS}${NODE_NAME}/agent-acl-tokens.hcl > /dev/null << EOF
acl {
  tokens {
    agent  = "${AGENT_TOKEN}"
    default  = "${DNS_TOK}"
    config_file_service_registration = "${AGENT_TOKEN}"
  }
}
EOF

  log "Clean remote node"
  
  remote_exec ${NODE_NAME} "sudo rm -rf ${CONSUL_CONFIG_DIR}* && \
                            sudo rm -rf ${CONSUL_DATA_DIR}* && \
                            sudo chmod g+w ${CONSUL_DATA_DIR}"

  _CONSUL_PID=`remote_exec ${NODE_NAME} "pidof consul"`
  if [ ! -z "${_CONSUL_PID}" ]; then
    remote_exec ${NODE_NAME} "sudo kill -9 ${_CONSUL_PID}"
  fi


  log "Copy configuration on client nodes"
  remote_copy ${NODE_NAME} "${STEP_ASSETS}${NODE_NAME}/*" "${CONSUL_CONFIG_DIR}" 
done

##########################################################
header2 "Start Consul client agents"

for node in ${NODES_ARRAY[@]}; do
  export NODE_NAME=${node}
  log "Starting consul process on ${NODE_NAME}"
  remote_exec ${NODE_NAME} \
    "/usr/bin/consul agent \
    -log-file=/tmp/consul-client \
    -config-dir=${CONSUL_CONFIG_DIR} > /tmp/consul-client.log 2>&1 &" 

  sleep 1

done


log_err "Consul Token: ${CONSUL_HTTP_TOKEN}"

log_err "Consul Token: ${CONSUL_HTTP_TOKEN}"

