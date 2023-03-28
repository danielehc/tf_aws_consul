#!/usr/bin/env bash

docker rm -f hashicups-frontend

SERVICE_MESH=false

if   [ "${SERVICE_MESH}" == true ]; then
    # Start Application on localhost
    NETWORK="--publish 127.0.0.1:3000:3000"
elif [ "${1}" == local ]; then
    # Start Application on localhost
    NETWORK="--publish 127.0.0.1:3000:3000"
else
    NETWORK="--network host"
fi

docker run \
  -d \
  ${NETWORK} \
  --restart unless-stopped \
  --env NEXT_PUBLIC_PUBLIC_API_URL=/ \
  --name hashicups-frontend hashicorpdemoapp/frontend:v1.0.9