# Incident Report: Service1 Stale Lockfile (2026-04-30)

**Issue**: KAN-7 - Service1 returning HTTP 500
**Date**: 2026-04-30
**Duration**: ~2 minutes
**Severity**: P2 - Service Unavailable

## Skill Used
`stale-lockfile` (from `.agents/skills/stale-lockfile/SKILL.md`)

## Diagnosis

Service1 was returning HTTP 500 errors due to a stale lockfile at `/tmp/service.lock`. The lockfile was left behind after a previous crash and was preventing the service from starting correctly.

**Initial Status Check**:
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

**Diagnostic Results**:
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

| Action | Risk Level | Justification |
|--------|------------|---------------|
| `get_all_service_status` | LOW | Read-only health check via HTTP |
| `diagnose_service1` | LOW | Read-only filesystem check for lockfile |
| `rm -f /tmp/service.lock` | MEDIUM | Removes temporary file only; service automatically recovers upon removal |
| `get_all_service_status` (verification) | LOW | Read-only health check via HTTP |

**Overall Risk**: MEDIUM (auto-approved per AGENTS.md)
- Lockfile is in `/tmp` (temporary directory)
- File removal is non-destructive to service data
- Service automatically recovers once lockfile is removed
- No service restart required

## Remediation

Executed `fix_service1` MCP tool to remove the stale lockfile:

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

Service1 returned to healthy status immediately after lockfile removal:

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

✅ **Success**: Service1 is now returning HTTP 200 and all services are operational.

## Root Cause

The lockfile at `/tmp/service.lock` was created during normal service operation but was not properly cleaned up when the service crashed. This prevented subsequent service restarts from proceeding normally.

## Prevention

- Implement proper signal handlers to clean up lockfiles on shutdown
- Consider using advisory locks with automatic cleanup
- Add monitoring for stale lockfiles older than expected service lifetime
- Implement health checks that detect and alert on lockfile-related failures

## References

- Skill: `.agents/skills/stale-lockfile/SKILL.md`
- MCP Tools: `get_all_service_status`, `diagnose_service1`, `fix_service1`
