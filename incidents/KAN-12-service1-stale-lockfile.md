# Incident Report: KAN-12 — service1 Stale Lockfile (HTTP 500)

**Jira Issue**: [KAN-12](https://rajiv-shah.atlassian.net/browse/KAN-12)  
**Date**: 2026-06-24  
**Severity**: P2 — service1 returning HTTP 500  
**Status**: Resolved ✅

---

## Skill Used

`stale-lockfile` — `.agents/skills/stale-lockfile/SKILL.md`

---

## Diagnosis

Initial health check confirmed service1 was the only unhealthy service.

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
  "recommended_action": "fix_service1"
}
```

**Root cause**: A stale `/tmp/service.lock` file was left behind after a previous crash, preventing service1 from starting correctly and causing HTTP 500 responses.

---

## Risk Assessment

| Action | Risk Level | Rationale |
|--------|------------|-----------|
| `get_all_service_status` | LOW | Read-only health check |
| `diagnose_service1` | LOW | Read-only — checks lockfile existence |
| `fix_service1` (`rm -f /tmp/service.lock`) | MEDIUM | Removes a temp lockfile only; service unaffected beyond unlocking startup |
| `get_all_service_status` (verification) | LOW | Read-only health check |

MEDIUM risk is **auto-approved** per `AGENTS.md` for the stale-lockfile scenario.

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

The stale lockfile `/tmp/service.lock` was removed successfully (`rm_returncode: 0`, `fixed: true`).

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

All services healthy. service1 returned to HTTP 200 immediately after lockfile removal.

---

## Actions Taken

| Step | Action | Risk | Result |
|------|--------|------|--------|
| 1 | `get_all_service_status` | LOW | Confirmed service1 HTTP 500 |
| 2 | `diagnose_service1` | LOW | Confirmed stale lockfile at `/tmp/service.lock` |
| 3 | `fix_service1` | MEDIUM | Removed lockfile; service1 immediately returned HTTP 200 |
| 4 | `get_all_service_status` | LOW | Verified all 3 services healthy (HTTP 200) |

---

*This incident report was created by an AI agent (OpenHands) on behalf of Rajiv Shah.*
