# Incident Report: KAN-8 — Service1 HTTP 500 (Stale Lockfile)

**Date**: 2026-04-01  
**Severity**: P2 — Production service returning HTTP 500  
**Resolved by**: OpenHands SRE Agent

---

## Skill Used

`stale-lockfile` — from `.agents/skills/stale-lockfile/SKILL.md`

---

## Diagnosis

Initial health check confirmed service1 was returning HTTP 500:

```json
{
  "service1": { "path": "/service1", "http_code": "500", "healthy": false },
  "service2": { "path": "/service2", "http_code": "500", "healthy": false },
  "service3": { "path": "/service3", "http_code": "500", "healthy": false }
}
```

Detailed diagnosis of service1 confirmed a stale lockfile at `/tmp/service.lock`:

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

**Root Cause**: A leftover `/tmp/service.lock` file from a previous crash was preventing service1 from serving requests.

---

## Risk Assessment

| Action | Risk Level | Justification |
|--------|------------|---------------|
| `get_all_service_status` | LOW | Read-only health check |
| `diagnose_service1` | LOW | Read-only lock file check |
| `rm -f /tmp/service.lock` | MEDIUM | Removes a temporary lock file only; service state is unaffected. Auto-approved per `AGENTS.md`. |
| `get_all_service_status` (verify) | LOW | Read-only health check |

---

## Remediation

Called `fix_service1` which executed `rm -f /tmp/service.lock` on the server:

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

Post-fix health check confirmed service1 is now healthy (HTTP 200):

```json
{
  "service1": { "path": "/service1", "http_code": "200", "healthy": true },
  "service2": { "path": "/service2", "http_code": "500", "healthy": false },
  "service3": { "path": "/service3", "http_code": "500", "healthy": false }
}
```

**Outcome**: ✅ Service1 is fully restored and returning HTTP 200.
