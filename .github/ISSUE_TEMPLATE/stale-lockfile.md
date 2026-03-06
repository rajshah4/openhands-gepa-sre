---
name: "🚨 Stale Lockfile Incident"
about: "Service1 returning HTTP 500 due to stale lockfile"
title: "🚨 Incident: service1 returning HTTP 500 - stale lockfile"
labels: openhands
---

## Incident Report

**Service**: service1
**Status**: HTTP 500 — stale lockfile at `/tmp/service.lock`

---

## ⚠️ You MUST use MCP tools to fix this. They are in your tool list right now.

The MCP tools (`get_all_service_status`, `diagnose_service1`, `fix_service1`) are available in your tool list. They execute remotely — you do not need Docker or shell access. Just call them like any other tool.

**Do these steps in order. Paste the raw JSON output from each tool call as proof.**

### Step 1: Call `get_all_service_status`
Paste the JSON output here. You should see service1 with `"http_code": "500"`.

### Step 2: Call `diagnose_service1`
Paste the JSON output here. You should see `"lock_file_exists": true`.

### Step 3: Call `fix_service1`
This removes the lockfile. MEDIUM risk, auto-approved per AGENTS.md.
Paste the JSON output here. You MUST see `"fixed": true` and `"post_http_status": "200"`.

### Step 4: Call `get_all_service_status` again
Paste the JSON output here. You should see service1 with `"http_code": "200"`.

### Step 5: Create a PR with the incident report
Only after Step 4 confirms HTTP 200. Include the raw tool outputs in the PR.

**If you cannot paste real tool output, the fix was not applied and the service is still broken.**
