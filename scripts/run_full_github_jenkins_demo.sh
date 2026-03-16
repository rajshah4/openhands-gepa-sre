#!/bin/bash
# Full demo runner:
# 1. Ensure local Jenkins demo is up
# 2. Run demo preflight
# 3. Break service1
# 4. Create a GitHub issue that triggers OpenHands Cloud
# 5. Let the GitHub PR webhook trigger Jenkins automatically

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO="${GITHUB_REPO:-rajshah4/openhands-sre}"
SCENARIO="${1:-stale_lockfile}"
TARGET_URL="${DEMO_TARGET_URL:-https://macbook-pro.tail21d104.ts.net}"
JENKINS_URL="${JENKINS_URL:-http://127.0.0.1:8081}"

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1" >&2
        exit 1
    fi
}

extract_issue_number() {
    sed -n 's|.*issues/\([0-9][0-9]*\)$|\1|p'
}

require_cmd gh
require_cmd docker
require_cmd python3

cd "$ROOT_DIR"

./scripts/start_jenkins_demo.sh
./scripts/demo_preflight.sh

echo "Preparing live demo state..."
docker exec openhands-gepa-demo touch /tmp/service.lock >/dev/null

echo "Creating GitHub issue for scenario: ${SCENARIO}"
issue_url="$(
    DEMO_TARGET_URL="$TARGET_URL" \
    python3 scripts/create_demo_issue.py --scenario "$SCENARIO" \
        | tee /tmp/openhands_demo_issue.log \
        | sed -n 's|✅ Issue created: ||p'
)"

if [[ -z "$issue_url" ]]; then
    echo "Failed to capture created issue URL" >&2
    exit 1
fi

issue_number="$(printf '%s\n' "$issue_url" | extract_issue_number)"
if [[ -z "$issue_number" ]]; then
    echo "Failed to parse issue number from: $issue_url" >&2
    exit 1
fi

echo "Issue created: ${issue_url}"
echo
echo "Demo started."
echo "  Issue:      ${issue_url}"
echo "  Jenkins:    ${JENKINS_URL}"
echo
echo "What happens next:"
echo "  1. OpenHands Cloud picks up the labeled issue."
echo "  2. OpenHands remediates the incident and creates a PR."
echo "  3. GitHub sends a PR webhook to the local demo server."
echo "  4. The webhook triggers Jenkins automatically and comments the result on the PR."
