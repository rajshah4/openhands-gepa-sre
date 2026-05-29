# Incident Report: KAN-3 — service1 HTTP 500 (Stale Lockfile)

**Date**: 2026-05-29  
**Severity**: Medium  
**Resolution Time**: < 5 minutes  

---

## Skill Used

`stale-lockfile` — `.agents/skills/stale-lockfile/SKILL.md`

---

## Diagnosis

Initial status check showed service1 returning HTTP 500 while service2 and service3 were healthy.

**`get_all_service_status` (initial):**
```json
{
  "service1": { "path": "/service1", "http_code": "500", "healthy": false },
  "service2": { "path": "/service2", "http_code": "200", "healthy": true },
  "service3": { "path": "/service3", "http_code": "200", "healthy": true }
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
  "recommended_action": "fix_service1",
  "next_step": "IMPORTANT: Call the fix_service1 tool NOW to remove the lockfile. This is MEDIUM risk and auto-approved per AGENTS.md."
}
```

**Root Cause**: A stale `/tmp/service.lock` file was left behind from a previous crash, preventing service1 from starting and causing HTTP 500 responses.

---

## Risk Assessment

| Action | Risk Level | Rationale |
|--------|-----------|-----------|
| `get_all_service_status` | LOW | Read-only health check |
| `diagnose_service1` | LOW | Read-only diagnosis |
| `fix_service1` (`rm -f /tmp/service.lock`) | MEDIUM | Removes only a temp lockfile; auto-approved per AGENTS.md |
| `get_all_service_status` (verify) | LOW | Read-only verification |

---

## Remediation

**`fix_service1`:**
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

The stale lockfile was removed successfully (`"fixed": true`).

---

## Verification

**`get_all_service_status` (post-fix):**
```json
{
  "service1": { "path": "/service1", "http_code": "200", "healthy": true },
  "service2": { "path": "/service2", "http_code": "200", "healthy": true },
  "service3": { "path": "/service3", "http_code": "200", "healthy": true }
}
```

All services are now healthy. service1 is returning HTTP 200. ✅

---

_This incident report was created by an AI agent (OpenHands) on behalf of the user._
