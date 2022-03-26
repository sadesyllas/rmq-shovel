#!/bin/bash

# https://github.com/rabbitmq/rabbitmq-server/tree/master/deps/rabbitmq_shovel_management
# curl -X GET -u <USER>:<PASS> .../api/shovels/%2f

pushd "$(dirname "$0")"

if ! [[ -f "./queues" ]]; then
  echo "\"./queues\" not found" >&2
  exit 1
fi

if ! [[ -f "./env.sh" ]]; then
  echo "\"./env.sh\" not found" >&2
  exit 1
fi

if ! [[ -f "./shovel.template.json" ]]; then
  echo "\"./shovel.template.json\" not found" >&2
  exit 1
fi

. ./env.sh

readarray -t queues < ./queues

i=${#queues[@]}
while [[ $i -ge 0 ]]; do
  x="$(echo "${queues[$i]}" | tr -d " ")"

  if [[ -n "$x" ]]; then
    SHOVEL_NAME="shovel_${queues[$i]}"

    cp -f ./shovel.template.json ./shovel.json
    sed -i -E 's|<NAME>|'"${SHOVEL_NAME}"'|g' ./shovel.json
    sed -i -E 's|<QUEUE>|'"${queues[$i]}"'|g' ./shovel.json
    sed -i -E 's|<SRC_URI>|'"${RMQ_SHOVEL_SRC_URI}"'|g' ./shovel.json
    sed -i -E 's|<DST_URI>|'"${RMQ_SHOVEL_DST_URI}"'|g' ./shovel.json

    echo "creating shovel \"${SHOVEL_NAME}\" for queue \"${queues[$i]}\" with definition:"
    cat ./shovel.json
    echo

    curl -sSf -X PUT -u "${RMQ_MANAGEMENT_USER}:${RMQ_MANAGEMENT_PASS}" -H 'Content-Type: application/json' -d @./shovel.json  "${RMQ_MANAGEMENT_URI}/api/parameters/shovel/${RMQ_MANAGEMENT_VHOST}/${SHOVEL_NAME}"

    # curl -sSf -X DELETE -u "${RMQ_MANAGEMENT_USER}:${RMQ_MANAGEMENT_PASS}" "${RMQ_MANAGEMENT_URI}/api/parameters/shovel/${RMQ_MANAGEMENT_VHOST}/${SHOVEL_NAME}"

    RES=$?

    rm -f ./shovel.json

    if [[ $RES -ne 0 ]]; then
      echo "failed to create shovel"
      exit $RES
    fi
  fi

  i=$[$i-1]
done

echo "all shovels created"
