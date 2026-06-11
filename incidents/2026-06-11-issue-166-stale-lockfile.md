# Incident Report: Issue #166 — Stale Lockfile on service1

**Date**: 2026-06-11
**Severity**: High (Service Down)
**Skill Used**: `stale-lockfile`
**Status**: Resolved ✅

## Diagnosis

`get_all_service_status` output:
```json
{
  "service1": { "path": "/service1", "http_code": "500", "healthy": false },
  "service2": { "path": "/service2", "http_code": "200", "healthy": true },
  "service3": { "path": "/service3", "http_code": "200", "healthy": true }
}
```

`diagnose_service1` output:
```json
{
  "service": "service1",
  "scenario": "stale_lockfile",
  "http_status": "500",
  "healthy": false,
  "lock_file_exists": true,
  "diagnosis": "Stale lockfile present - needs removal",
  "recommended_action": "fix_service1",
  "next_step": "IMPORTANT: Call the fix_service1 tool NOW to remove the lockfile. This is MEDIUM risk and auto-approved per AGENTS.md."
}
```

Root cause: `/tmp/service.lock` was left behind from a previous crash, preventing service1 from starting cleanly.

## Risk Assessment

| Action | Risk Level | Rationale |
|--------|------------|-----------|
| `get_all_service_status` | LOW | Read-only health check |
| `diagnose_service1` | LOW | Read-only diagnostic |
| `fix_service1` (`rm -f /tmp/service.lock`) | MEDIUM | Removes a temp lockfile only; auto-approved per AGENTS.md |
| `get_all_service_status` (verification) | LOW | Read-only health check |

## Remediation

`fix_service1` output:
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

`get_all_service_status` after fix:
```json
{
  "service1": { "path": "/service1", "http_code": "200", "healthy": true },
  "service2": { "path": "/service2", "http_code": "200", "healthy": true },
  "service3": { "path": "/service3", "http_code": "200", "healthy": true }
}
```

All services healthy. Issue resolved.
