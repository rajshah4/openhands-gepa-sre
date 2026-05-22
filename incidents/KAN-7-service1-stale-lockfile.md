# Incident Report: KAN-7 — service1 HTTP 500 (Stale Lockfile)

**Date**: 2026-05-22  
**Issue**: KAN-7  
**Resolved by**: OpenHands SRE Agent

---

## Skill Used

`stale-lockfile` — `.agents/skills/stale-lockfile/SKILL.md`

---

## Diagnosis

`get_all_service_status` confirmed service1 was the only unhealthy service:

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
  "recommended_action": "fix_service1",
  "next_step": "IMPORTANT: Call the fix_service1 tool NOW to remove the lockfile. This is MEDIUM risk and auto-approved per AGENTS.md."
}
```

**Root cause**: A previous crash left `/tmp/service.lock` on disk. On restart, service1 detected the stale lock and entered an error state, returning HTTP 500 on all requests.

---

## Risk Assessment

| Action | Risk Level | Rationale |
|--------|------------|-----------|
| `get_all_service_status` | LOW | Read-only health check |
| `diagnose_service1` | LOW | Read-only — checks file existence |
| `fix_service1` (`rm -f /tmp/service.lock`) | MEDIUM | Removes a temporary lockfile only; no data loss; auto-approved per AGENTS.md |
| Post-fix `get_all_service_status` | LOW | Read-only verification check |

---

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

`fixed: true` and `post_http_status: "200"` confirm successful remediation.

---

## Verification

Final `get_all_service_status` confirms all services healthy:

```json
{
  "service1": { "path": "/service1", "http_code": "200", "healthy": true },
  "service2": { "path": "/service2", "http_code": "200", "healthy": true },
  "service3": { "path": "/service3", "http_code": "200", "healthy": true }
}
```

service1 is now returning HTTP 200. Incident resolved.
