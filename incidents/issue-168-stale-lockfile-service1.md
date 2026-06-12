# Incident Report: Issue #168 — Stale Lockfile on service1

**Date**: 2026-06-12  
**Issue**: [#168](../../issues/168)  
**Service**: service1 (`/service1`)  
**Skill Used**: `stale-lockfile`

---

## Skill Used

`.agents/skills/stale-lockfile` — Stale Lockfile Recovery runbook

## Diagnosis

`diagnose_service1` confirmed that `/tmp/service.lock` was present, causing service1 to return HTTP 500.

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

Initial `get_all_service_status`:

```json
{
  "service1": { "path": "/service1", "http_code": "500", "healthy": false },
  "service2": { "path": "/service2", "http_code": "200", "healthy": true },
  "service3": { "path": "/service3", "http_code": "200", "healthy": true }
}
```

## Risk Assessment

| Action | Risk Level | Rationale |
|--------|------------|-----------|
| `get_all_service_status` | LOW | Read-only health check |
| `diagnose_service1` | LOW | Read-only — checks if lockfile exists |
| `fix_service1` (`rm -f /tmp/service.lock`) | MEDIUM | Removes a temp file only; service unaffected if file is absent |
| `get_all_service_status` (verification) | LOW | Read-only health check |

MEDIUM risk is auto-approved per `AGENTS.md` for stale lockfile remediation.

## Remediation

`fix_service1` executed `rm -f /tmp/service.lock` remotely via MCP:

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

Post-fix `get_all_service_status` confirmed all services healthy:

```json
{
  "service1": { "path": "/service1", "http_code": "200", "healthy": true },
  "service2": { "path": "/service2", "http_code": "200", "healthy": true },
  "service3": { "path": "/service3", "http_code": "200", "healthy": true }
}
```

service1 now returns HTTP 200. Incident resolved.
