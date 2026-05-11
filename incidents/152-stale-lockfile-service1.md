# Incident #152: service1 returning HTTP 500 (stale lockfile)

Fixes #152

## Skill Used
`stale-lockfile` (see `.agents/skills/stale-lockfile/SKILL.md`)

## Diagnosis
service1 `/service1` was returning HTTP 500. The runbook for stale lockfiles
was triggered by the error message in the issue: `stale lockfile present at /tmp/service.lock`.

Pre-fix status (`get_all_service_status`):
```json
{
  "service1": {"path": "/service1", "http_code": "500", "healthy": false},
  "service2": {"path": "/service2", "http_code": "200", "healthy": true},
  "service3": {"path": "/service3", "http_code": "200", "healthy": true}
}
```

Root cause confirmation (`diagnose_service1`):
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

A previous crash left `/tmp/service.lock` on disk; on restart the service
refused to serve traffic because it interpreted the file as another instance
holding the lock.

## Risk Assessment

| Action | Risk | Rationale |
|--------|------|-----------|
| `get_all_service_status` | LOW | Read-only health probe. |
| `diagnose_service1` | LOW | Read-only check for lockfile + HTTP status. |
| `fix_service1` (`rm -f /tmp/service.lock`) | MEDIUM | Removes a single temp file in `/tmp`. Reversible (the service recreates it on startup) and auto-approved per `AGENTS.md`. No data is lost. |

## Remediation
Executed `fix_service1`, which removed the stale lockfile remotely on the
service host:
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
Post-fix status (`get_all_service_status`):
```json
{
  "service1": {"path": "/service1", "http_code": "200", "healthy": true},
  "service2": {"path": "/service2", "http_code": "200", "healthy": true},
  "service3": {"path": "/service3", "http_code": "200", "healthy": true}
}
```

service1 now returns HTTP 200 and the issue's expected behavior
(`"status": "ok"`) is restored.
