# Incident Report: Issue #107 — service1 Stale Lockfile

**Date**: 2026-03-30  
**Service**: service1 (`/service1`)  
**Severity**: P2 — Service Unavailable (HTTP 500)

## Skill Used

`stale-lockfile` — `.agents/skills/stale-lockfile/SKILL.md`

## Diagnosis

Confirmed via `get_all_service_status` that service1 was returning HTTP 500. Subsequent `diagnose_service1` confirmed a stale lockfile at `/tmp/service.lock`.

**`get_all_service_status` (pre-fix):**
```json
{
  "service1": { "path": "/service1", "http_code": "500", "healthy": false },
  "service2": { "path": "/service2", "http_code": "500", "healthy": false },
  "service3": { "path": "/service3", "http_code": "500", "healthy": false }
}
```

**`diagnose_service1`:**
```json
{
  "service": "service1",
  "scenario": "stale_lockfile",
  "http_status": "500",
  "healthy": false,
  "lock_file_exists": true,
  "diagnosis": "Stale lockfile present - needs removal",
  "recommended_action": "fix_service1"
}
```

## Risk Assessment

| Action | Risk Level | Rationale |
|--------|------------|-----------|
| `get_all_service_status` | LOW | Read-only health check |
| `diagnose_service1` | LOW | Read-only diagnostic check |
| `fix_service1` (rm -f /tmp/service.lock) | MEDIUM | Removes temp file only; auto-approved per AGENTS.md |
| `get_all_service_status` (post-fix) | LOW | Read-only verification |

## Remediation

Called `fix_service1` to remove the stale lockfile `/tmp/service.lock`.

**`fix_service1` output:**
```json
{
  "service": "service1",
  "action": "rm -f /tmp/service.lock",
  "risk_level": "MEDIUM",
  "pre_http_status": "500",
  "post_http_status": "200",
  "fixed": true,
  "rm_returncode": 0,
  "rm_error": null
}
```

## Verification

**`get_all_service_status` (post-fix):**
```json
{
  "service1": { "path": "/service1", "http_code": "200", "healthy": true },
  "service2": { "path": "/service2", "http_code": "500", "healthy": false },
  "service3": { "path": "/service3", "http_code": "500", "healthy": false }
}
```

service1 is now returning HTTP 200 and is healthy. ✅

## Root Cause

A stale lockfile at `/tmp/service.lock` was left behind after the previous deployment/crash. The service checks for the lockfile on startup and returns HTTP 500 while it exists.

## Resolution

Removed `/tmp/service.lock` via the `fix_service1` MCP tool. Service recovered immediately to HTTP 200.
