# Incident Report: Issue #154 — service1 HTTP 500 (Stale Lockfile)

## Skill Used
`stale-lockfile` (`.agents/skills/stale-lockfile/SKILL.md`)

## Diagnosis
service1 `/service1` endpoint was returning HTTP 500 due to a stale lockfile at
`/tmp/service.lock` left over from a previous crashed instance.

Initial status check:

```json
{
  "service1": {"path": "/service1", "http_code": "500", "healthy": false},
  "service2": {"path": "/service2", "http_code": "200", "healthy": true},
  "service3": {"path": "/service3", "http_code": "200", "healthy": true}
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
  "recommended_action": "fix_service1"
}
```

## Risk Assessment

| Action | Risk | Rationale |
|--------|------|-----------|
| `get_all_service_status` | LOW | Read-only health check |
| `diagnose_service1` | LOW | Read-only filesystem check |
| `fix_service1` (`rm -f /tmp/service.lock`) | MEDIUM | Removes a temp lockfile only; auto-approved per `AGENTS.md` and the `stale-lockfile` skill. Reversible (service will recreate lockfile on next start). |

## Remediation
Invoked the `fix_service1` MCP tool which removed `/tmp/service.lock` on the
service container.

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
Post-remediation health check confirms all services healthy:

```json
{
  "service1": {"path": "/service1", "http_code": "200", "healthy": true},
  "service2": {"path": "/service2", "http_code": "200", "healthy": true},
  "service3": {"path": "/service3", "http_code": "200", "healthy": true}
}
```

service1 now returns HTTP 200 as expected.
