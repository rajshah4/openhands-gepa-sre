# Incident #158: service1 Stale Lockfile (HTTP 500)

**Date**: 2026-05-14
**Service**: service1 (`/service1`)
**Severity**: High (service returning HTTP 500)
**Status**: Resolved ✅

## Skill Used

`.agents/skills/stale-lockfile`

## Diagnosis

`get_all_service_status` confirmed service1 was returning HTTP 500:

```json
{
  "service1": { "path": "/service1", "http_code": "500", "healthy": false },
  "service2": { "path": "/service2", "http_code": "200", "healthy": true },
  "service3": { "path": "/service3", "http_code": "200", "healthy": true }
}
```

`diagnose_service1` confirmed a stale lockfile at `/tmp/service.lock`:

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

| Action | Risk | Rationale |
|--------|------|-----------|
| `get_all_service_status` | LOW | Read-only health check |
| `diagnose_service1` | LOW | Read-only file existence check |
| `fix_service1` (rm -f /tmp/service.lock) | MEDIUM | Removes temp file only; auto-approved per AGENTS.md |

## Remediation

Called `fix_service1` to remove the stale lockfile:

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

`get_all_service_status` confirmed all services healthy after remediation:

```json
{
  "service1": { "path": "/service1", "http_code": "200", "healthy": true },
  "service2": { "path": "/service2", "http_code": "200", "healthy": true },
  "service3": { "path": "/service3", "http_code": "200", "healthy": true }
}
```

## Root Cause

A stale lockfile at `/tmp/service.lock` was left over from a previous crash or deployment. The service checks for this file on startup/health check and returns HTTP 500 when it exists.

## Resolution

The lockfile was removed via the `fix_service1` MCP tool (`rm -f /tmp/service.lock`), restoring service1 to HTTP 200.
