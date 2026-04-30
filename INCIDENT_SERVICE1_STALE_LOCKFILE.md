# Incident Report: Service1 HTTP 500 - Stale Lockfile

**Date**: 2026-04-30
**Issue**: KAN-10
**Status**: Resolved

## Skill Used
`stale-lockfile` (from `.agents/skills/stale-lockfile/SKILL.md`)

## Diagnosis

Service1 was returning HTTP 500 errors due to a stale lockfile at `/tmp/service.lock` that remained after a previous crash.

**Initial Status Check:**
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

**Diagnostic Results:**
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
| `get_all_service_status` | LOW | Read-only health check via HTTP |
| `diagnose_service1` | LOW | Read-only check for lockfile existence |
| `fix_service1` (rm -f /tmp/service.lock) | MEDIUM | Removes temporary lockfile only. Auto-approved per AGENTS.md. Service unaffected by removal - only prevents startup conflicts. |
| `get_all_service_status` (verification) | LOW | Read-only health check via HTTP |

**Justification for MEDIUM risk action:**
- Action modifies filesystem state (removes a file)
- However, lockfile is in `/tmp` (temporary directory)
- File only serves to prevent concurrent startup
- No data loss risk - lockfile contains no application data
- Service restart would naturally clear this file
- Auto-approved per security policy in AGENTS.md

## Remediation

**Action Taken:**
Executed `fix_service1` MCP tool which ran `rm -f /tmp/service.lock` on the service container.

**Fix Results:**
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

The lockfile was successfully removed with no errors (returncode: 0).

## Verification

**Post-Fix Status Check:**
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

✅ **Service1 is now healthy and returning HTTP 200**
✅ **All services are operational**

## Root Cause

The lockfile mechanism in service1 is designed to prevent concurrent instances from starting. When service1 crashes unexpectedly, the lockfile at `/tmp/service.lock` persists on disk. On restart, the service checks for this file and refuses to start if it exists, resulting in HTTP 500 errors.

## Prevention

Consider implementing one of the following:
1. **Lock file cleanup on startup**: Check file age/staleness before refusing to start
2. **PID validation**: Store process ID in lockfile and validate it's still running
3. **Timeout mechanism**: Auto-expire lockfiles older than X seconds
4. **Graceful shutdown handler**: Remove lockfile on SIGTERM/SIGINT

## Timeline

1. Service1 crash (unknown trigger) - lockfile left behind
2. Service restart attempted - detected existing lockfile, refused to start
3. HTTP 500 errors observed
4. Incident detected and diagnosed using `diagnose_service1` tool
5. Fix applied using `fix_service1` tool (removed stale lockfile)
6. Service1 recovered - verified with `get_all_service_status`
