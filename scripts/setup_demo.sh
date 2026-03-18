#!/bin/bash
# OpenHands SRE Demo Setup Script
# Builds the local stack, stages the stale-lockfile demo, starts MCP,
# and verifies Tailscale/Funnel readiness when available.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONTAINER_NAME="openhands-gepa-demo"
IMAGE_NAME="openhands-gepa-sre-target:latest"
APP_PORT="15000"
MCP_PORT="8080"
MCP_LOG="/tmp/mcp_server.log"
MCP_PID_FILE="/tmp/openhands_sre_mcp.pid"
FUNNEL_URL=""
WEBHOOK_STATUS="not configured"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo -e "${RED}✗ Missing required command: $1${NC}"
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

    echo -e "${RED}✗ ${label} did not become healthy: ${url}${NC}"
    exit 1
}

service_http_code() {
    curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${APP_PORT}/$1"
}

ensure_mcp_server() {
    echo ""
    echo -n "Starting MCP server... "

    if curl -fsS "http://127.0.0.1:${MCP_PORT}/" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Already running${NC}"
        return 0
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

    : > "$MCP_LOG"
    (
        cd "$ROOT_DIR"
        nohup uv run python mcp_server/server.py >>"$MCP_LOG" 2>&1 &
        echo $! > "$MCP_PID_FILE"
    )
    wait_for_http "http://127.0.0.1:${MCP_PORT}/" "MCP server"
    echo -e "${GREEN}✓ Listening on port ${MCP_PORT}${NC}"
}

check_tailscale() {
    echo ""
    echo -n "Checking Tailscale... "
    if ! command -v tailscale >/dev/null 2>&1; then
        echo -e "${YELLOW}○ Not installed${NC}"
        echo "  Install from: https://tailscale.com/download"
        return 0
    fi

    if ! tailscale status >/dev/null 2>&1; then
        echo -e "${YELLOW}○ Not connected${NC}"
        echo "  Run 'tailscale up' to connect"
        return 0
    fi

    echo -e "${GREEN}✓ Connected${NC}"
    echo ""
    echo -n "Checking Tailscale Funnel... "

    local funnel_status
    funnel_status="$(tailscale funnel status 2>&1 || true)"
    FUNNEL_URL="$(
        printf '%s\n' "$funnel_status" \
            | grep -E '^https://' \
            | awk '{print $1}' \
            | grep -v ':8443$' \
            | head -1
    )"
    if [[ -z "$FUNNEL_URL" ]]; then
        FUNNEL_URL="$(
            printf '%s\n' "$funnel_status" \
                | grep -E '^https://' \
                | awk '{print $1}' \
                | head -1
        )"
    fi

    if [[ -z "$FUNNEL_URL" ]]; then
        echo -e "${YELLOW}○ Funnel not running${NC}"
        echo "  Run:"
        echo "    tailscale funnel --set-path / 15000"
        echo "    tailscale funnel --set-path /mcp 8080"
        return 0
    fi

    echo -e "${GREEN}✓ Funnel URL detected${NC}"
    echo -e "  Public URL: ${GREEN}${FUNNEL_URL}${NC}"

    if printf '%s\n' "$funnel_status" | grep -qE '15000|/ '; then
        echo -e "  Demo service path: ${GREEN}configured${NC}"
    else
        echo -e "  Demo service path: ${YELLOW}not found in funnel status${NC}"
    fi

    if printf '%s\n' "$funnel_status" | grep -qE '8080|/mcp'; then
        echo -e "  MCP path: ${GREEN}configured${NC}"
    else
        echo -e "  MCP path: ${YELLOW}not found in funnel status${NC}"
    fi
}

configure_github_webhook() {
    echo ""
    echo -n "Configuring GitHub webhook... "

    if ! command -v gh >/dev/null 2>&1; then
        echo -e "${YELLOW}○ gh not installed${NC}"
        echo "  Run later: python3 scripts/setup_github_jenkins_webhook.py"
        return 0
    fi

    if ! gh auth status >/dev/null 2>&1; then
        echo -e "${YELLOW}○ gh not authenticated${NC}"
        echo "  Run 'gh auth login' and then: python3 scripts/setup_github_jenkins_webhook.py"
        return 0
    fi

    if [[ -z "$FUNNEL_URL" ]]; then
        echo -e "${YELLOW}○ Funnel URL not available${NC}"
        echo "  Run later after Funnel is configured: python3 scripts/setup_github_jenkins_webhook.py"
        return 0
    fi

    if PUBLIC_MCP_URL="${FUNNEL_URL}/mcp" python3 "$ROOT_DIR/scripts/setup_github_jenkins_webhook.py" >/tmp/setup_github_jenkins_webhook.log 2>&1; then
        WEBHOOK_STATUS="configured"
        echo -e "${GREEN}✓ Configured${NC}"
    else
        WEBHOOK_STATUS="failed"
        echo -e "${YELLOW}○ Failed${NC}"
        echo "  See: /tmp/setup_github_jenkins_webhook.log"
    fi
}

echo "=========================================="
echo "  OpenHands SRE Demo Setup"
echo "=========================================="
echo ""

require_cmd docker
require_cmd curl
require_cmd uv

echo -n "Checking Docker... "
if docker info >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Docker is running${NC}"
else
    echo -e "${RED}✗ Docker is not running${NC}"
    echo "Please start Docker Desktop and try again."
    exit 1
fi

echo ""
echo "Building target service Docker image..."
docker build -t "$IMAGE_NAME" "$ROOT_DIR/target_service"
echo -e "${GREEN}✓ Image built${NC}"

echo ""
echo -n "Recreating demo container... "
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
docker run -d -p "${APP_PORT}:5000" -e REQUIRED_API_KEY=secret --name "$CONTAINER_NAME" "$IMAGE_NAME" >/dev/null
echo -e "${GREEN}✓ Container started${NC}"

echo ""
echo -n "Waiting for app health... "
wait_for_http "http://127.0.0.1:${APP_PORT}/" "Demo service"
echo -e "${GREEN}✓ Base app reachable${NC}"

echo ""
echo -n "Preparing demo state... "
docker exec "$CONTAINER_NAME" touch /tmp/ready.flag >/dev/null
docker exec "$CONTAINER_NAME" touch /tmp/service.lock >/dev/null
echo -e "${GREEN}✓ service1 broken, service2/service3 healthy${NC}"

ensure_mcp_server

echo ""
echo "Refreshing Jenkins demo image and controller..."
"$ROOT_DIR/scripts/start_jenkins_demo.sh" --rebuild

check_tailscale
configure_github_webhook

SERVICE1_CODE="$(service_http_code service1)"
SERVICE2_CODE="$(service_http_code service2)"
SERVICE3_CODE="$(service_http_code service3)"
MCP_STATUS="down"
if curl -fsS "http://127.0.0.1:${MCP_PORT}/" >/dev/null 2>&1; then
    MCP_STATUS="up"
fi

echo ""
echo "=========================================="
echo "  Setup Complete!"
echo "=========================================="
echo ""
echo "Local verification:"
echo "  service1: HTTP ${SERVICE1_CODE} (expected 500 for stale-lockfile demo)"
echo "  service2: HTTP ${SERVICE2_CODE} (expected 200)"
echo "  service3: HTTP ${SERVICE3_CODE} (expected 200)"
echo "  MCP:      ${MCP_STATUS} on http://127.0.0.1:${MCP_PORT}/mcp"
echo ""
echo "Local URLs:"
echo "  Index:    http://127.0.0.1:${APP_PORT}/"
echo "  Service1: http://127.0.0.1:${APP_PORT}/service1"
echo "  Service2: http://127.0.0.1:${APP_PORT}/service2"
echo "  Service3: http://127.0.0.1:${APP_PORT}/service3"
echo "  MCP:      http://127.0.0.1:${MCP_PORT}/mcp"
echo "  MCP Log:  ${MCP_LOG}"
echo ""

if [[ -n "$FUNNEL_URL" ]]; then
    echo "Public URLs (via Tailscale Funnel):"
    echo "  Service1: ${FUNNEL_URL}/service1"
    echo "  MCP:      ${FUNNEL_URL}/mcp"
    echo "  Webhook:  ${FUNNEL_URL}/mcp/github-webhook"
    echo ""
    echo "Next steps:"
    echo "  export DEMO_TARGET_URL=${FUNNEL_URL}"
    echo "  uv run python scripts/create_demo_issue.py --scenario stale_lockfile"
else
    echo "For OpenHands Cloud integration, configure Funnel:"
    echo "  tailscale funnel --set-path / 15000"
    echo "  tailscale funnel --set-path /mcp 8080"
fi
echo ""
echo "Quick commands:"
echo "  Re-break service1: docker exec ${CONTAINER_NAME} touch /tmp/service.lock"
echo "  Verify MCP:        uv run python scripts/test_mcp_agent.py"
echo "  Setup webhook:     python3 scripts/setup_github_jenkins_webhook.py"
echo "  Fix manually:      ./scripts/fix_demo.sh service1"
echo "  Webhook status:    ${WEBHOOK_STATUS}"
echo ""
