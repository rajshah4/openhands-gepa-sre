# Incident Report: Issue #116 — Stale Lockfile on service1

**Date**: 2026-04-06
**Severity**: High (service down, HTTP 500)
**Service**: service1 (`/service1`)
**Resolved By**: OpenHands SRE Agent

---

## Skill Used

`stale-lockfile` — `.agents/skills/stale-lockfile/SKILL.md`

---

## Diagnosis

**Initial service status** (`get_all_service_status`):
```json
{
  "service1": { "path": "/service1", "http_code": "500", "healthy": false },
  "service2": { "path": "/service2", "http_code": "500", "healthy": false },
  "service3": { "path": "/service3", "http_code": "500", "healthy": false }
}
```

**Service1 diagnosis** (`diagnose_service1`):
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

Root cause: `/tmp/service.lock` was left behind after a previous crash, blocking service startup.

---

## Risk Assessment

| Action | Risk Level | Rationale |
|--------|-----------|-----------|
| `get_all_service_status` | LOW | Read-only health check |
| `diagnose_service1` | LOW | Read-only diagnostic check |
| `rm -f /tmp/service.lock` | MEDIUM | Removes only a temp lockfile; auto-approved per AGENTS.md |
| Post-fix verification | LOW | Read-only health check |

---

## Remediation

**Fix applied** (`fix_service1`):
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

**Post-fix service status** (`get_all_service_status`):
```json
{
  "service1": { "path": "/service1", "http_code": "200", "healthy": true },
  "service2": { "path": "/service2", "http_code": "500", "healthy": false },
  "service3": { "path": "/service3", "http_code": "500", "healthy": false }
}
```

✅ service1 now returns HTTP 200 — incident resolved.
