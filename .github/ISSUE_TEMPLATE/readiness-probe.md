---
name: "🚨 Readiness Probe Failure"
about: "Service2 readiness probe failing - missing ready flag"
title: "🚨 Incident: service2 readiness probe failing"
labels: openhands
---

## Incident Report

**Service**: service2
**Status**: HTTP 500 — missing readiness flag at `/tmp/ready.flag`

---

## ⚠️ You MUST use MCP tools to fix this. They are in your tool list right now.

The MCP tools (`get_all_service_status`, `diagnose_service2`, `fix_service2`) are available in your tool list. They execute remotely — you do not need Docker or shell access. Just call them like any other tool.

**Do these steps in order. Paste the raw JSON output from each tool call as proof.**

### Step 1: Call `get_all_service_status`
Paste the JSON output here. You should see service2 with `"http_code": "500"`.

### Step 2: Call `diagnose_service2`
Paste the JSON output here. You should see `"ready_flag_exists": false`.

### Step 3: Call `fix_service2`
This creates the readiness flag. LOW risk.
Paste the JSON output here. You MUST see `"fixed": true` and `"post_http_status": "200"`.

### Step 4: Call `get_all_service_status` again
Paste the JSON output here. You should see service2 with `"http_code": "200"`.

### Step 5: Create a PR with the incident report
Only after Step 4 confirms HTTP 200. Include the raw tool outputs in the PR.

**If you cannot paste real tool output, the fix was not applied and the service is still broken.**
