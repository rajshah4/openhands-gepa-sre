#!/bin/bash

set -euo pipefail

CONTAINER_NAME="openhands-sre-jenkins"

docker rm -f "$CONTAINER_NAME"
