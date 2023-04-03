#!/usr/bin/env bash

# ++-----------
# ||   01 - Setup Bastion Host
# ++------

# ++-----------------+
# || Variables       |
# ++-----------------+

# Create necessary directories to operate
mkdir -p ${ASSETS}
mkdir -p ${LOGS}

# PATH=$PATH:/home/app/bin
# SSH_OPTS="StrictHostKeyChecking=accept-new"

## Instruqt compatibility
if [[ ! -z "${INSTRUQT_PARTICIPANT_ID}" ]]; then
    FQDN_SUFFIX=".$INSTRUQT_PARTICIPANT_ID.svc.cluster.local"
else
    FQDN_SUFFIX=""
fi

# ++-----------------+
# || Functions       |
# ++-----------------+
print_env() {
  if [ ! -z $1 ] ; then

    if [[ -f "${ASSETS}/env-$1.conf" ]] && [[ -s "${ASSETS}/env-$1.conf" ]] ;  then

      cat ${ASSETS}/env-$1.conf

    elif [ "$1" == "consul" ]; then

      ## If the environment file does not exist prints current variables
      ## This is used to export them in a file afted defining them in the script.
      echo " export CONSUL_HTTP_ADDR=${CONSUL_HTTP_ADDR}"
      echo " export CONSUL_HTTP_TOKEN=${CONSUL_HTTP_TOKEN}"
      echo " export CONSUL_HTTP_SSL=${CONSUL_HTTP_SSL}"
      echo " export CONSUL_CACERT=${CONSUL_CACERT}"
      echo " export CONSUL_TLS_SERVER_NAME=${CONSUL_TLS_SERVER_NAME}"
      echo " export CONSUL_FQDN_ADDR=${CONSUL_FQDN_ADDR}"

    elif [ "$1" == "vault" ]; then

      echo " export VAULT_ADDR=${VAULT_ADDR}"
      echo " export VAULT_TOKEN=${VAULT_TOKEN}"

    fi

  else
    # If no argument is passed prints all available environment files
    for env_file in `find ${ASSETS} -name env-*`; do
      
      echo -e "\033[1m\033[31mENV: ${env_file}\033[0m"
      cat ${env_file}
      echo ""
    done
  fi
}


# ++-----------------+
# || Begin           |
# ++-----------------+

if [ "${START_MONITORING_SUITE}" == "true" ]; then

  log "Starting monitoring suite on Bastion Host"
  bash ${ASSETS}scenario/start_monitoring_suite.sh

fi

