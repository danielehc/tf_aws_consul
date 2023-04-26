#!/usr/bin/env bash

# ++-----------------+
# || Variables       |
# ++-----------------+

export STEP_ASSETS="${ASSETS}scenario/conf/"

export NODES_ARRAY=( "hashicups-db" "hashicups-api" "hashicups-frontend" "hashicups-nginx" )

# ++-----------------+
# || Begin           |
# ++-----------------+

header1 "Configuring Consul service mesh monitoring"

mkdir -p ${STEP_ASSETS}monitoring

header2 "Consul server monitoring"

## ~todo make all servers discoverable from bastion host
for i in `seq 0 "$((SERVER_NUMBER-1))"`; do

  log "Generate Grafana Agent configuration for consul-server-$i "
  tee ${STEP_ASSETS}monitoring/consul-server-$i.yaml > /dev/null << EOF
server:
  log_level: debug

metrics:
  global:
    scrape_interval: 60s
    remote_write:
    - url: http://${PROMETHEUS_URI}:9009/api/v1/push
  configs:
  - name: default
    scrape_configs:
    - job_name: consul-server
      metrics_path: '/v1/agent/metrics'
      static_configs:
        - targets: ['127.0.0.1:8500']

logs:
  configs:
  - name: default
    clients:
      - url: http://${PROMETHEUS_URI}:3100/loki/api/v1/push
    positions:
      filename: /tmp/positions.yaml
    scrape_configs:
     - job_name: consul-server
       static_configs:
       - targets: 
           - localhost
         labels:
           job: logs
           host: consul-server-$i
           __path__: /tmp/*.log
EOF

  log "Stop pre-existing agent processes"
  ## Stop already running Envoy processes (helps idempotency)
  _G_AGENT_PID=`remote_exec consul-server-$i "pidof grafana-agent"`
  if [ ! -z "${_G_AGENT_PID}" ]; then
    remote_exec consul-server-$i "sudo kill -9 ${_G_AGENT_PID}"
  fi

  log "Copy configuration"
  remote_copy consul-server-$i "${STEP_ASSETS}monitoring/consul-server-$i.yaml" "~/grafana-agent.yaml" 

  log "Start Grafana agent"
  remote_exec consul-server-$i "bash -c 'grafana-agent -config.file ~/grafana-agent.yaml > /tmp/grafana-agent.log 2>&1 &'"

done

header2 "Consul client monitoring"

for node in ${NODES_ARRAY[@]}; do
  NODE_NAME=${node}
  log "Generate Grafana Agent configuration for ${NODE_NAME} "

  tee ${STEP_ASSETS}monitoring/${NODE_NAME}.yaml > /dev/null << EOF
server:
  log_level: debug

metrics:
  global:
    scrape_interval: 60s
    remote_write:
    - url: http://${PROMETHEUS_URI}:9009/api/v1/push
  configs:
  - name: default
    scrape_configs:
    - job_name: ${NODE_NAME}
      metrics_path: '/stats/prometheus'
      static_configs:
        - targets: ['127.0.0.1:19000']
    - job_name: consul-agent
      metrics_path: '/v1/agent/metrics'
      static_configs:
        - targets: ['127.0.0.1:8500']

logs:
  configs:
  - name: default
    clients:
      - url: http://${PROMETHEUS_URI}:3100/loki/api/v1/push
    positions:
      filename: /tmp/positions.yaml
    scrape_configs:
     - job_name: service-mesh-apps
       static_configs:
       - targets: 
           - localhost
         labels:
           job: logs
           host: ${NODE_NAME}
           __path__: /tmp/*.log
EOF

  log "Stop pre-existing agent processes"
  ## Stop already running Envoy processes (helps idempotency)
  _G_AGENT_PID=`remote_exec ${NODE_NAME} "pidof grafana-agent"`
  if [ ! -z "${_G_AGENT_PID}" ]; then
    remote_exec ${NODE_NAME} "sudo kill -9 ${_G_AGENT_PID}"
  fi

  log "Copy configuration"
  remote_copy ${NODE_NAME} "${STEP_ASSETS}monitoring/${NODE_NAME}.yaml" "~/grafana-agent.yaml" 

  log "Start Grafana agent"
  remote_exec ${NODE_NAME} "bash -c 'grafana-agent -config.file ~/grafana-agent.yaml > /tmp/grafana-agent.log 2>&1 &'"

done


exit 0



##########################################################
header2 "Generate Consul clients configuration"

for node in ${NODES_ARRAY[@]}; do
  NODE_NAME=${node}
  header3 "Modify service configuration for ${NODE_NAME}"
  
  log "Copy service files into Consul configuration directory"
  remote_exec ${NODE_NAME} "cp ${CONSUL_CONFIG_DIR}svc/service_mesh/*.hcl ${CONSUL_CONFIG_DIR}"

  log "Reload Consul configuration"
  _agent_token=`cat ${STEP_ASSETS}secrets/acl-token-${NODE_NAME}.json | jq -r ".SecretID"`

  # log_warn "Agent token: ${_agent_token}"

  remote_exec ${NODE_NAME} "/usr/bin/consul reload -token=${_agent_token}"

done

##########################################################
header2 "Starting Envoy sidecar proxies"

for node in ${NODES_ARRAY[@]}; do
  NODE_NAME=${node}
  header3 "Start Envoy sidecar for ${NODE_NAME}"
  _agent_token=`cat ${STEP_ASSETS}secrets/acl-token-${NODE_NAME}.json | jq -r ".SecretID"`
  
  ## !todo Remove before fly. Test with bootstrap token
  # _agent_token=${CONSUL_HTTP_TOKEN}
  
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
header2 "Generate catch all intention"

tee ${STEP_ASSETS}config-intentions-default-allow.hcl > /dev/null << EOF
Kind = "service-intentions"
Name = "*"
Sources = [
  {
    Name   = "*"
    Action = "allow"
  }
]
EOF

consul config write ${STEP_ASSETS}config-intentions-default-allow.hcl



##########################################################
header2 "Restart Services on local interface"

for node in ${NODES_ARRAY[@]}; do
  NODE_NAME=${node}
  
  if [ "${NODE_NAME}" == "hashicups-nginx" ]; then
    log_warn "Not restarting ${NODE_NAME} to provide access"
    remote_exec ${NODE_NAME} "bash ~/start_service.sh mesh" > /dev/null 2>&1
  else
    log "Restarting ${NODE_NAME}"
    remote_exec ${NODE_NAME} "bash ~/start_service.sh local" > /dev/null 2>&1
  fi
done

log_err "Consul Token: ${CONSUL_HTTP_TOKEN}"
