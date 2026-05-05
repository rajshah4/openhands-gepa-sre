# Incident Report: Service1 Stale Lockfile (Issue #149)

## Skill Used
`stale-lockfile` (from `.agents/skills/stale-lockfile/`)

## Diagnosis

Service1 was returning HTTP 500 Internal Server Error due to a stale lockfile at `/tmp/service.lock`.

### Tool Outputs

**Initial Status Check (`get_all_service_status`):**
```json
{
  "service1": {
    "path": "/service1",
    "http_code": "500",
    "healthy": false
  },
  "service2": {
    "path": "/service2",
    "http_code": "200",
    "healthy": true
  },
  "service3": {
    "path": "/service3",
    "http_code": "200",
    "healthy": true
  }
}
```

**Diagnosis (`diagnose_service1`):**
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

## Risk Assessment

| Action | Risk Level | Justification |
|--------|------------|---------------|
| `get_all_service_status` | LOW | Read-only health check |
| `diagnose_service1` | LOW | Read-only diagnosis |
| `rm -f /tmp/service.lock` | MEDIUM | Removes temp file only, service unaffected. Auto-approved per repository security policy. |
| `get_all_service_status` (verification) | LOW | Read-only health check |

## Remediation

Executed `fix_service1` MCP tool to remove the stale lockfile remotely.

**Fix Output (`fix_service1`):**
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

Service1 restored to healthy state, returning HTTP 200.

**Verification Status Check (`get_all_service_status`):**
```json
{
  "service1": {
    "path": "/service1",
    "http_code": "200",
    "healthy": true
  },
  "service2": {
    "path": "/service2",
    "http_code": "200",
    "healthy": true
  },
  "service3": {
    "path": "/service3",
    "http_code": "200",
    "healthy": true
  }
}
```

## Resolution

✅ Service1 is now healthy and operational
✅ All services returning HTTP 200
✅ Incident resolved successfully

Closes #149
