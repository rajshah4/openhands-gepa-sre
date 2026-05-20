# Incident Report: KAN-8 — service1 HTTP 500 (Stale Lockfile)

**Date**: 2026-05-20  
**Issue**: KAN-8  
**Reported by**: rajshah4  
**Resolved by**: OpenHands SRE Agent  

---

## Skill Used

`stale-lockfile` — `.agents/skills/stale-lockfile/SKILL.md`

---

## Diagnosis

Initial status check via `get_all_service_status` confirmed service1 was returning HTTP 500:

```json
{
  "service1": { "path": "/service1", "http_code": "500", "healthy": false },
  "service2": { "path": "/service2", "http_code": "200", "healthy": true },
  "service3": { "path": "/service3", "http_code": "200", "healthy": true }
}
```

`diagnose_service1` confirmed the presence of a stale lockfile at `/tmp/service.lock`:

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

**Root Cause**: A previous crash left `/tmp/service.lock` on disk. On restart, service1 detected the lockfile and refused to serve requests, returning HTTP 500.

---

## Risk Assessment

| Action | Risk Level | Justification |
|--------|-----------|---------------|
| `get_all_service_status` | LOW | Read-only health check |
| `diagnose_service1` | LOW | Read-only diagnostic check |
| `fix_service1` (`rm -f /tmp/service.lock`) | MEDIUM (auto-approved) | Removes only the stale temp lockfile; no data loss; service unaffected during removal |
| `get_all_service_status` (verification) | LOW | Read-only health check |

Per `AGENTS.md`, MEDIUM risk actions involving temp file removal are **auto-approved**.

---

## Remediation

`fix_service1` was executed, removing `/tmp/service.lock`:

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

Post-fix `get_all_service_status` confirmed all services healthy:

```json
{
  "service1": { "path": "/service1", "http_code": "200", "healthy": true },
  "service2": { "path": "/service2", "http_code": "200", "healthy": true },
  "service3": { "path": "/service3", "http_code": "200", "healthy": true }
}
```

**service1 is restored to HTTP 200. Incident resolved.**

---

*This incident report was created by an AI agent (OpenHands) on behalf of rajshah4.*
