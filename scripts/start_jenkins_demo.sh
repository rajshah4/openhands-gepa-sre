#!/bin/bash
# Build and run a local Jenkins controller for the OpenHands SRE demo.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE_NAME="openhands-sre-jenkins:latest"
CONTAINER_NAME="openhands-sre-jenkins"
HOST_PORT="${JENKINS_PORT:-8081}"
AGENT_PORT="${JENKINS_AGENT_PORT:-50001}"
JENKINS_HOME_DIR="${ROOT_DIR}/.jenkins_home"
WORKSPACE_DIR="${ROOT_DIR}"
REBUILD_IMAGE=0

usage() {
    cat <<'EOF'
Usage: ./scripts/start_jenkins_demo.sh [--rebuild]

Starts the local Jenkins controller for the demo.

Options:
  --rebuild   Rebuild the Jenkins image before starting
  -h, --help  Show this help text
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rebuild)
            REBUILD_IMAGE=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage
            exit 1
            ;;
    esac
done

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1" >&2
        exit 1
    fi
}

wait_for_http() {
    local url="$1"
    local attempts="${2:-60}"
    local delay="${3:-2}"
    local i

    for ((i = 1; i <= attempts; i++)); do
        if curl -fsS "$url" >/dev/null 2>&1; then
            return 0
        fi
        sleep "$delay"
    done

    echo "Jenkins did not become healthy: $url" >&2
    exit 1
}

require_cmd docker
require_cmd curl
require_cmd mkdir

mkdir -p "$JENKINS_HOME_DIR"
mkdir -p "$JENKINS_HOME_DIR/init.groovy.d"
cp "$ROOT_DIR"/jenkins/init.groovy.d/*.groovy "$JENKINS_HOME_DIR/init.groovy.d/"

if [[ "$REBUILD_IMAGE" -eq 1 ]] || ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    echo "Building Jenkins demo image..."
    docker build -t "$IMAGE_NAME" "$ROOT_DIR/jenkins"
else
    echo "Reusing existing Jenkins demo image: $IMAGE_NAME"
fi

echo "Starting Jenkins demo container..."
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
docker run -d \
    --name "$CONTAINER_NAME" \
    -u root \
    -p "${HOST_PORT}:8080" \
    -p "${AGENT_PORT}:50000" \
    -v "$JENKINS_HOME_DIR:/var/jenkins_home" \
    -v "$WORKSPACE_DIR:/workspace/openhands-sre" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    "$IMAGE_NAME" >/dev/null

wait_for_http "http://127.0.0.1:${HOST_PORT}/login"

echo
echo "Jenkins is running."
echo "  URL:      http://127.0.0.1:${HOST_PORT}"
echo "  Login:    admin / admin"
echo "  Workspace mounted at: /workspace/openhands-sre"
echo
echo "Create a Pipeline job and point it at:"
echo "  /workspace/openhands-sre/Jenkinsfile"
echo
echo "Or run inside Jenkins:"
echo "  cd /workspace/openhands-sre && START_STACK=0 ./scripts/jenkins_verify_demo.sh"
