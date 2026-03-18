#!/bin/bash
# Restart-safe demo launcher: starts the Docker service, MCP server, local
# Jenkins controller, verifies a healthy baseline, and then stages the demo.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONTAINER_NAME="openhands-gepa-demo"
IMAGE_NAME="openhands-gepa-sre-target:latest"
PYTHON_BIN="${PYTHON_BIN:-$ROOT_DIR/.venv/bin/python}"
APP_PORT="${APP_PORT:-15000}"
MCP_PORT="${MCP_PORT:-8080}"
MCP_LOG="/tmp/mcp_server.log"
MCP_PID_FILE="/tmp/openhands_sre_mcp.pid"
MCP_SESSION_NAME="${MCP_SESSION_NAME:-openhands-sre-mcp}"
APP_HOST="${APP_HOST:-127.0.0.1}"
MCP_HOST="${MCP_HOST:-127.0.0.1}"
WEBHOOK_SECRET_FILE="${WEBHOOK_SECRET_FILE:-${ROOT_DIR}/.demo_webhook_secret}"
RUN_LOCAL_JENKINS="${RUN_LOCAL_JENKINS:-1}"
RUN_PREFLIGHT="${RUN_PREFLIGHT:-1}"

REBUILD_IMAGE=0
BREAK_SCENARIO=""
LEAVE_HEALTHY=0

usage() {
    cat <<'EOF'
Usage: ./scripts/start_demo.sh [--rebuild] [--healthy] [--break service1|service2|service3|all]

Starts the local demo stack after a reboot:
  - ensures the Docker image exists
  - recreates the demo container on port 15000
  - starts the MCP server on port 8080 in the background
  - starts the local Jenkins controller on port 8081
  - runs the demo preflight checks
  - stages all three services as broken by default

Options:
  --rebuild               Rebuild the Docker image before starting
  --healthy               Leave all services healthy after startup
  --break service1        Create /tmp/service.lock in the container
  --break service2        Remove /tmp/ready.flag in the container
  --break service3        Restart without REQUIRED_API_KEY
  --break all             Break service1, service2, and service3
  -h, --help              Show this help text
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rebuild)
            REBUILD_IMAGE=1
            shift
            ;;
        --healthy)
            LEAVE_HEALTHY=1
            BREAK_SCENARIO=""
            shift
            ;;
        --break)
            if [[ $# -lt 2 ]]; then
                echo "Missing value for --break" >&2
                usage
                exit 1
            fi
            BREAK_SCENARIO="$2"
            shift 2
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

if [[ "$LEAVE_HEALTHY" -eq 0 ]] && [[ -z "$BREAK_SCENARIO" ]]; then
    BREAK_SCENARIO="all"
fi

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1" >&2
        exit 1
    fi
}

wait_for_http() {
    local url="$1"
    local label="$2"
    local attempts="${3:-30}"
    local delay="${4:-1}"
    local i

    for ((i = 1; i <= attempts; i++)); do
        if curl -fsS "$url" >/dev/null 2>&1; then
            return 0
        fi
        sleep "$delay"
    done

    echo "$label did not become healthy: $url" >&2
    return 1
}

ensure_image() {
    if [[ "$REBUILD_IMAGE" -eq 1 ]] || ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
        echo "Building Docker image..."
        docker build -t "$IMAGE_NAME" "$ROOT_DIR/target_service"
    else
        echo "Docker image already present: $IMAGE_NAME"
    fi
}

restart_container() {
    local include_api_key="${1:-1}"

    echo "Recreating demo container..."
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    if [[ "$include_api_key" == "1" ]]; then
        docker run -d -p "${APP_PORT}:5000" -e REQUIRED_API_KEY=secret --name "$CONTAINER_NAME" "$IMAGE_NAME" >/dev/null
    else
        docker run -d -p "${APP_PORT}:5000" --name "$CONTAINER_NAME" "$IMAGE_NAME" >/dev/null
    fi
    wait_for_http "http://${APP_HOST}:${APP_PORT}/" "Demo service"
    docker exec "$CONTAINER_NAME" touch /tmp/ready.flag >/dev/null
}

start_mcp_server() {
    if curl -fsS "http://${MCP_HOST}:${MCP_PORT}/" >/dev/null 2>&1; then
        echo "MCP server already healthy on port ${MCP_PORT}"
        return 0
    fi

    if command -v tmux >/dev/null 2>&1 && tmux has-session -t "$MCP_SESSION_NAME" >/dev/null 2>&1; then
        tmux kill-session -t "$MCP_SESSION_NAME" >/dev/null 2>&1 || true
        sleep 1
    fi

    if [[ -f "$MCP_PID_FILE" ]]; then
        local old_pid
        old_pid="$(cat "$MCP_PID_FILE")"
        if kill -0 "$old_pid" >/dev/null 2>&1; then
            kill "$old_pid" >/dev/null 2>&1 || true
            sleep 1
        fi
        rm -f "$MCP_PID_FILE"
    fi

    echo "Starting MCP server in background..."
    : > "$MCP_LOG"
    if [[ -z "${GITHUB_WEBHOOK_SECRET:-}" ]] && [[ -f "$WEBHOOK_SECRET_FILE" ]]; then
        GITHUB_WEBHOOK_SECRET="$(tr -d '\r\n' < "$WEBHOOK_SECRET_FILE")"
        export GITHUB_WEBHOOK_SECRET
    fi
    if command -v tmux >/dev/null 2>&1; then
        tmux new-session -d -s "$MCP_SESSION_NAME" \
            "cd '$ROOT_DIR' && export DEMO_LOCAL_URL='http://${APP_HOST}:${APP_PORT}' GITHUB_WEBHOOK_SECRET='${GITHUB_WEBHOOK_SECRET:-}' && '$PYTHON_BIN' mcp_server/server.py >>'$MCP_LOG' 2>&1"
        tmux list-panes -t "$MCP_SESSION_NAME" -F '#{pane_pid}' | head -1 > "$MCP_PID_FILE"
    else
        (
            cd "$ROOT_DIR"
            DEMO_LOCAL_URL="http://${APP_HOST}:${APP_PORT}" GITHUB_WEBHOOK_SECRET="${GITHUB_WEBHOOK_SECRET:-}" \
                nohup "$PYTHON_BIN" mcp_server/server.py >>"$MCP_LOG" 2>&1 < /dev/null &
            echo $! > "$MCP_PID_FILE"
        )
    fi

    wait_for_http "http://${MCP_HOST}:${MCP_PORT}/" "MCP server"
}

break_services() {
    case "$BREAK_SCENARIO" in
        "")
            return 0
            ;;
        service1)
            echo "Breaking service1 (stale lockfile)..."
            docker exec "$CONTAINER_NAME" touch /tmp/service.lock >/dev/null
            ;;
        service2)
            echo "Breaking service2 (missing readiness flag)..."
            docker exec "$CONTAINER_NAME" rm -f /tmp/ready.flag >/dev/null
            ;;
        service3)
            echo "Breaking service3 (missing REQUIRED_API_KEY)..."
            restart_container 0
            ;;
        all)
            echo "Breaking service1, service2, and service3..."
            restart_container 0
            docker exec "$CONTAINER_NAME" touch /tmp/service.lock >/dev/null
            docker exec "$CONTAINER_NAME" rm -f /tmp/ready.flag >/dev/null
            ;;
        *)
            echo "Unsupported --break scenario: $BREAK_SCENARIO" >&2
            exit 1
            ;;
    esac
}

print_service_status() {
    local service="$1"
    local payload

    payload="$(curl -sS "http://${APP_HOST}:${APP_PORT}/${service}")"
    python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("status","?"))' <<<"$payload"
}

require_cmd docker
require_cmd curl
require_cmd uv
require_cmd python3
if [[ "$RUN_PREFLIGHT" -eq 1 ]]; then
    require_cmd gh
fi

if [[ ! -x "$PYTHON_BIN" ]]; then
    echo "Python runtime not found at $PYTHON_BIN; running uv sync to create .venv"
    (cd "$ROOT_DIR" && uv sync --frozen)
fi

if ! docker info >/dev/null 2>&1; then
    echo "Docker is not running. Start Docker Desktop and rerun ./scripts/start_demo.sh" >&2
    exit 1
fi

echo "Starting OpenHands SRE demo..."
ensure_image
restart_container 1
start_mcp_server
if [[ "$RUN_LOCAL_JENKINS" -eq 1 ]]; then
    echo "Starting Jenkins controller..."
    "$ROOT_DIR/scripts/start_jenkins_demo.sh"
fi
if [[ "$RUN_PREFLIGHT" -eq 1 ]]; then
    echo "Running demo preflight..."
    "$ROOT_DIR/scripts/demo_preflight.sh"
fi
break_services

echo
echo "Demo URLs:"
echo "  Index:    http://${APP_HOST}:${APP_PORT}/"
echo "  Service1: http://${APP_HOST}:${APP_PORT}/service1"
echo "  Service2: http://${APP_HOST}:${APP_PORT}/service2"
echo "  Service3: http://${APP_HOST}:${APP_PORT}/service3"
echo
echo "Current status:"
echo "  service1: $(print_service_status service1)"
echo "  service2: $(print_service_status service2)"
echo "  service3: $(print_service_status service3)"
echo
echo "MCP server:"
echo "  URL:  http://${MCP_HOST}:${MCP_PORT}/mcp"
echo "  Log:  ${MCP_LOG}"
if [[ -f "$MCP_PID_FILE" ]]; then
    echo "  PID:  $(cat "$MCP_PID_FILE")"
fi
if command -v tmux >/dev/null 2>&1; then
    echo "  Tmux: ${MCP_SESSION_NAME}"
fi
echo
if [[ "$RUN_LOCAL_JENKINS" -eq 1 ]]; then
    echo "Jenkins:"
    echo "  URL:  http://127.0.0.1:${JENKINS_PORT:-8081}"
    echo "  Job:  openhands-sre-demo"
fi
if [[ "$RUN_PREFLIGHT" -eq 1 ]] && [[ -f "$WEBHOOK_SECRET_FILE" ]]; then
    echo "GitHub webhook:"
    echo "  Secret file: ${WEBHOOK_SECRET_FILE}"
    echo "  Setup:       python3 scripts/setup_github_jenkins_webhook.py"
fi
echo
echo "Next steps:"
echo "  Start healthy:    ./scripts/start_demo.sh --healthy"
echo "  Break service1:   docker exec ${CONTAINER_NAME} touch /tmp/service.lock"
echo "  Break service2:   docker exec ${CONTAINER_NAME} rm -f /tmp/ready.flag"
echo "  Break service3:   docker rm -f ${CONTAINER_NAME} && docker run -d -p ${APP_PORT}:5000 --name ${CONTAINER_NAME} ${IMAGE_NAME}"
echo "  Test MCP path:    uv run python scripts/test_mcp_agent.py"
echo "  Jenkins checks:   START_STACK=0 ./scripts/jenkins_verify_demo.sh"
echo "  Watch MCP calls:  tail -f ${MCP_LOG}"
echo "  Create issue:     uv run python scripts/create_demo_issue.py --scenario stale_lockfile"
