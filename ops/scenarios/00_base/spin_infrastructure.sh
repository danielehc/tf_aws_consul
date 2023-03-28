#!/usr/bin/env bash

source ./00_local_vars.env

## Docker tag for resources
DK_TAG="instruqt"
DK_NET="instruqt-net"

## Define primary datacenter and domain for the sandbox Consul DC
DOMAIN="learn"
PRIMARY_DATACENTER="local"

## Create network
log "Creating Network ${DK_NET}"
docker network create ${DK_NET} --subnet=172.20.0.0/24 --label tag=${DK_TAG} > /dev/null 2>&1


## Create Operator node
log "Starting Operator"
EXTRA_PARAMS=""
if [ "${EXPOSE_CONTAINER_PORTS}" == "true" ] ; then
  EXTRA_PARAMS="-p 7777:7777 ${EXTRA_PARAMS}"
fi
spin_container_param "operator" "${DK_NET}" "${DOCKER_REPOSITORY}/${IMAGE_NAME_BASE}:${IMAGE_TAG}" "${EXTRA_PARAMS}"


log "Starting Consul server node"
EXTRA_PARAMS="" #"--dns=172.20.0.2 --dns-search=learn"
if [ "${EXPOSE_CONTAINER_PORTS}" == "true" ]; then
    EXTRA_PARAMS="-p 1443:443 ${EXTRA_PARAMS}"
fi
spin_container_param "consul" "${DK_NET}" "${DOCKER_REPOSITORY}/${IMAGE_NAME_BASE}:${IMAGE_TAG}" "${EXTRA_PARAMS}"


log "Starting Service node Nginx"
EXTRA_PARAMS=""
if [ "${EXPOSE_CONTAINER_PORTS}" == "true" ]; then
    EXTRA_PARAMS="-p 1443:1443 ${EXTRA_PARAMS}"
fi
spin_container_param "hashicups-nginx" "${DK_NET}" "${DOCKER_REPOSITORY}/${IMAGE_NAME_NGINX}:${IMAGE_TAG}" "${EXTRA_PARAMS}"


log "Starting Service node frontend"
EXTRA_PARAMS=""
# if [ "${EXPOSE_CONTAINER_PORTS}" == "true" ]; then
#     EXTRA_PARAMS="-p 1443:1443 ${EXTRA_PARAMS}"
# fi
spin_container_param "hashicups-frontend" "${DK_NET}" "${DOCKER_REPOSITORY}/${IMAGE_NAME_FRONTEND}:${IMAGE_TAG}" "${EXTRA_PARAMS}"


log "Starting Service node API"
EXTRA_PARAMS=""
# if [ "${EXPOSE_CONTAINER_PORTS}" == "true" ]; then
#     EXTRA_PARAMS="-p 1443:1443 ${EXTRA_PARAMS}"
# fi
spin_container_param "hashicups-api" "${DK_NET}" "${DOCKER_REPOSITORY}/${IMAGE_NAME_API}:${IMAGE_TAG}" "${EXTRA_PARAMS}"


log "Starting Service node DB"
EXTRA_PARAMS=""
# if [ "${EXPOSE_CONTAINER_PORTS}" == "true" ]; then
#     EXTRA_PARAMS="-p 1443:1443 ${EXTRA_PARAMS}"
# fi
spin_container_param "hashicups-db" "${DK_NET}" "${DOCKER_REPOSITORY}/${IMAGE_NAME_DATABASE}:${IMAGE_TAG}" "${EXTRA_PARAMS}"

# Resets extra params
EXTRA_PARAMS=""
