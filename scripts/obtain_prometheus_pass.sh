#!/bin/bash

PROM_PASS=$(oc extract secret/htpasswd -n istio-system --to=- --keys=rawPassword)

echo "######################################################"
echo "## Red Hat Service Mesh Prometheus password encoded ##"
echo "######################################################"

jq -rn --arg x ${PROM_PASS} '$x|@uri'