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
  queue="$(echo "${queues[$i]}" | tr -d " ")"

  if [[ -n "$queue" ]]; then
    SHOVEL_NAME="shovel_${queue}"

    cp -f ./shovel.template.json ./shovel.json
    sed -i -E 's|<NAME>|'"${SHOVEL_NAME}"'|g' ./shovel.json
    sed -i -E 's|<QUEUE>|'"${queue}"'|g' ./shovel.json
    sed -i -E 's|<SRC_URI>|'"${RMQ_SHOVEL_SRC_URI}"'|g' ./shovel.json
    sed -i -E 's|<DST_URI>|'"${RMQ_SHOVEL_DST_URI}"'|g' ./shovel.json

    echo "creating shovel \"${SHOVEL_NAME}\" for queue \"${queue}\" with definition:"
    cat ./shovel.json
    echo

    # add the `shovel_` exchange

    curl -sSf -X PUT -u "${RMQ_MANAGEMENT_USER}:${RMQ_MANAGEMENT_PASS}" -H 'Content-Type: application/json' -d '{"type":"fanout","auto_delete":false,"durable":true,"internal":false,"arguments":{}}'  "${RMQ_MANAGEMENT_URI}/api/exchanges/${RMQ_MANAGEMENT_VHOST}/${SHOVEL_NAME}"

    RES=$?
    if [[ $RES -ne 0 ]]; then
      echo "failed to add the shovel exchange \"${SHOVEL_NAME}\""
      exit $RES
    fi

    # add the `shovel_` exchange binding

    curl -sSf -X POST -u "${RMQ_MANAGEMENT_USER}:${RMQ_MANAGEMENT_PASS}" -H 'Content-Type: application/json' -d '{"routing_key":"", "arguments":{}}'  "${RMQ_MANAGEMENT_URI}/api/bindings/${RMQ_MANAGEMENT_VHOST}/e/${SHOVEL_NAME}/q/${queue}"

    RES=$?
    if [[ $RES -ne 0 ]]; then
      echo "failed to add the shovel exchange binding"
      exit $RES
    fi

    # create the shovel

    curl -sSf -X PUT -u "${RMQ_MANAGEMENT_USER}:${RMQ_MANAGEMENT_PASS}" -H 'Content-Type: application/json' -d @./shovel.json  "${RMQ_MANAGEMENT_URI}/api/parameters/shovel/${RMQ_MANAGEMENT_VHOST}/${SHOVEL_NAME}"

    # curl -sSf -X DELETE -u "${RMQ_MANAGEMENT_USER}:${RMQ_MANAGEMENT_PASS}" "${RMQ_MANAGEMENT_URI}/api/parameters/shovel/${RMQ_MANAGEMENT_VHOST}/${SHOVEL_NAME}"

    RES=$?
    if [[ $RES -ne 0 ]]; then
      echo "failed to create the shovel"
      exit $RES
    fi

    # delete the `shovel_` exchange

    curl -sSf -X DELETE -u "${RMQ_MANAGEMENT_USER}:${RMQ_MANAGEMENT_PASS}" -H 'Content-Type: application/json' -d '{"routing_key":"", "arguments":{}}'  "${RMQ_MANAGEMENT_URI}/api/exchanges/${RMQ_MANAGEMENT_VHOST}/${SHOVEL_NAME}"

    RES=$?
    if [[ $RES -ne 0 ]]; then
      echo "failed to delete the shovel exchange"
      exit $RES
    fi
  fi

  i=$[$i-1]
done

rm -f ./shovel.json

echo "all shovels created"
