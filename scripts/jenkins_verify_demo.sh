#!/bin/bash
# Jenkins validation for the OpenHands SRE demo.
# This keeps Jenkins in the post-remediation validation role.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_BASE_URL="${APP_BASE_URL:-http://127.0.0.1:15000}"
MCP_HEALTH_URL="${MCP_HEALTH_URL:-http://127.0.0.1:8080/}"
MCP_URL="${MCP_URL:-http://127.0.0.1:8080/mcp}"
START_STACK="${START_STACK:-1}"

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1" >&2
        exit 1
    fi
}

http_code() {
    curl -sS -o /dev/null -w "%{http_code}" "$1"
}

check_status() {
    local url="$1"
    local expected="$2"
    local label="$3"
    local actual

    actual="$(http_code "$url")"
    if [[ "$actual" != "$expected" ]]; then
        echo "${label} failed: expected HTTP ${expected}, got ${actual} (${url})" >&2
        exit 1
    fi
    echo "${label}: HTTP ${actual}"
}

require_cmd curl
require_cmd python3
require_cmd uv

cd "$ROOT_DIR"

if [[ "$START_STACK" == "1" ]]; then
    ./scripts/start_demo.sh
fi

echo "Running Jenkins validation against the live demo stack..."
check_status "${APP_BASE_URL}/" "200" "Index"
check_status "${APP_BASE_URL}/service1" "200" "Service1"
check_status "${APP_BASE_URL}/service2" "200" "Service2"
check_status "${APP_BASE_URL}/service3" "200" "Service3"
check_status "${MCP_HEALTH_URL}" "200" "MCP health"

echo
echo "Running MCP connectivity check..."
uv run python scripts/test_mcp_agent.py --url "$MCP_URL"

echo
echo "Running integration tests..."
uv run python -m unittest discover -s tests -p 'test_*.py' -v

echo
echo "Jenkins validation completed successfully."
