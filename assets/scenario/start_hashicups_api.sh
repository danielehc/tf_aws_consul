#!/usr/bin/env bash

## Remove pre-existing instances
docker rm -f hashicups-api-payments hashicups-api-product hashicups-api-public
sudo rm -rf /home/admin/conf.json

SERVICE_MESH=false



if   [ "${SERVICE_MESH}" == true ]; then
  # Start Application on localhost
  NETWORK_PAY="--publish 127.0.0.1:8080:8080"
  NETWORK_PRO="--publish 127.0.0.1:9090:9090"
  NETWORK_PUB="--publish 127.0.0.1:8081:8081"
  BIND_PRO="127.0.0.1"
  BIND_PUB="127.0.0.1"
  DB="127.0.0.1"
  PROD="127.0.0.1"
  PAY="127.0.0.1"
elif [ "${1}" == local ]; then
  # Start Application on localhost
  NETWORK_PAY="--publish 127.0.0.1:8080:8080"
  NETWORK_PRO="--publish 127.0.0.1:9090:9090"
  NETWORK_PUB="--publish 127.0.0.1:8081:8081"
  BIND_PRO="127.0.0.1"
  BIND_PUB="127.0.0.1"
  DB="127.0.0.1"
  PROD="127.0.0.1"
  PAY="127.0.0.1"
else
  NETWORK_PAY="--network host"
  NETWORK_PRO="--network host"
  NETWORK_PUB="--network host"
  DB="10.0.4.240"
  PROD="localhost"
  PAY="localhost"
fi

## Payments
docker run \
  -d \
  ${NETWORK_PAY} \
  --restart unless-stopped \
  --name hashicups-api-payments hashicorpdemoapp/payments:latest

## Product API
tee /home/admin/conf.json > /dev/null << EOF
{
  "db_connection": "host=${DB} port=5432 user=postgres password=password dbname=products sslmode=disable",
  "bind_address": "${BIND_PRO}:9090",
  "metrics_address": "${BIND_PRO}:9103"
}
EOF

docker run \
  -d \
  ${NETWORK_PRO} \
  --restart unless-stopped \
  --volume /home/admin/conf.json:/conf.json \
  --name hashicups-api-product hashicorpdemoapp/product-api:v0.0.22

## Public API
docker run \
  -d \
  ${NETWORK_PUB} \
  --restart unless-stopped \
  --env PRODUCT_API_URI=http://${PROD}:9090 \
  --env PAYMENT_API_URI=http://${PAY}:8080 \
  --env  BIND_ADDRESS="${BIND_PUB}:8081" \
  --name hashicups-api-public hashicorpdemoapp/public-api:v0.0.7