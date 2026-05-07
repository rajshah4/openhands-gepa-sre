# Incident Report: KAN-9 — service1 returning HTTP 500

## Skill Used
`stale-lockfile` (`.agents/skills/stale-lockfile/SKILL.md`)

## Diagnosis
service1 was returning HTTP 500. Diagnostic confirmed a stale lockfile at `/tmp/service.lock`.

`get_all_service_status` (initial):
```json
{
  "service1": {"path": "/service1", "http_code": "500", "healthy": false},
  "service2": {"path": "/service2", "http_code": "200", "healthy": true},
  "service3": {"path": "/service3", "http_code": "200", "healthy": true}
}
```

`diagnose_service1`:
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
| `diagnose_service1` | LOW | Read-only inspection of lockfile presence |
| `fix_service1` (`rm -f /tmp/service.lock`) | MEDIUM | Removes a temp lockfile only; reversible and auto-approved per `AGENTS.md` |

## Remediation
Invoked `fix_service1` to remove the stale `/tmp/service.lock`.

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
`get_all_service_status` (post-fix):
```json
{
  "service1": {"path": "/service1", "http_code": "200", "healthy": true},
  "service2": {"path": "/service2", "http_code": "200", "healthy": true},
  "service3": {"path": "/service3", "http_code": "200", "healthy": true}
}
```

service1 is now healthy (HTTP 200). Incident resolved.

---
_This incident report was created by an AI agent (OpenHands) on behalf of the user._
