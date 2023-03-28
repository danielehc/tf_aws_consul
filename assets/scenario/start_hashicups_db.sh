#!/usr/bin/env bash

docker rm -f hashicups-db

SERVICE_MESH=false

if   [ "${SERVICE_MESH}" == true ]; then
    # Start Application on localhost
    NETWORK="--publish 127.0.0.1:5432:5432"
elif [ "${1}" == local ]; then
    # Start Application on localhost
    NETWORK="--publish 127.0.0.1:5432:5432"
else
    NETWORK="--network host"
fi


docker run \
  -d \
  ${NETWORK} \
  --restart unless-stopped \
  --env POSTGRES_DB=products \
  --env POSTGRES_PASSWORD=password \
  --env POSTGRES_USER=postgres \
  --name hashicups-db hashicorpdemoapp/product-api-db:v0.0.22