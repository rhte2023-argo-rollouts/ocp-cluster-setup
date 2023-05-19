#!/bin/bash
##
# Create web terminal 
##

podman login quay.io
podman login registry.redhat.io 
podman build ./scripts/files/webterminal -t quay.io/acidonpe/web-terminal-tooling-rhel8-custom:latest
podman push quay.io/acidonpe/web-terminal-tooling-rhel8-custom:latest

# TEST
## podman run -it quay.io/acidonpe/web-terminal-tooling-rhel8-custom:latest bash