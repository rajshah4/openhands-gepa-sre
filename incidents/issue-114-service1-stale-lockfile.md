# Incident Report: Issue #114 — service1 Stale Lockfile

**Date**: 2026-04-06
**Severity**: P2 — Service Degraded
**Affected Service**: service1 (`/service1`)

---

## Skill Used

`stale-lockfile` (`.agents/skills/stale-lockfile/SKILL.md`)

---

## Diagnosis

`get_all_service_status` confirmed service1 was returning HTTP 500:

```json
{
  "service1": { "path": "/service1", "http_code": "500", "healthy": false },
  "service2": { "path": "/service2", "http_code": "500", "healthy": false },
  "service3": { "path": "/service3", "http_code": "500", "healthy": false }
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

Root cause: A previous process crash left `/tmp/service.lock` on disk. On restart, the service detected the stale lockfile and refused to serve traffic, returning HTTP 500.

---

## Risk Assessment

| Action | Risk Level | Justification |
|--------|-----------|---------------|
| `get_all_service_status` | LOW | Read-only health check |
| `diagnose_service1` | LOW | Read-only lock file check |
| `fix_service1` (`rm -f /tmp/service.lock`) | MEDIUM | Removes a temp file only; no data loss; auto-approved per AGENTS.md |
| `get_all_service_status` (verify) | LOW | Read-only health check |

---

## Remediation

`fix_service1` was called to remove the stale lockfile. Tool output:

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

---

## Verification

`get_all_service_status` confirmed service1 is now returning HTTP 200:

```json
{
  "service1": { "path": "/service1", "http_code": "200", "healthy": true },
  "service2": { "path": "/service2", "http_code": "500", "healthy": false },
  "service3": { "path": "/service3", "http_code": "500", "healthy": false }
}
```

Service1 is healthy. Incident resolved.
