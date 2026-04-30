# Incident Report: KAN-7 - Service1 Returning HTTP 500

**Date**: 2026-04-30  
**Issue**: Service1 returning HTTP 500 errors  
**Status**: ✅ RESOLVED

## Skill Used

`stale-lockfile` - Located at `.agents/skills/stale-lockfile/SKILL.md`

This skill addresses service failures caused by stale lockfiles remaining after crashes, which prevent the service from restarting properly.

## Diagnosis

Initial investigation confirmed service1 was returning HTTP 500 errors.

### Tool Output 1: Initial Status Check
```json
{
  "service1": {
    "path": "/service1",
    "http_code": "500",
    "healthy": false
  },
  "service2": {
    "path": "/service2",
    "http_code": "500",
    "healthy": false
  },
  "service3": {
    "path": "/service3",
    "http_code": "500",
    "healthy": false
  }
}
```

### Tool Output 2: Diagnostic Results
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

**Root Cause**: A stale lockfile at `/tmp/service.lock` was preventing service1 from starting properly. This typically occurs when a service crashes without cleaning up its lockfile.

## Risk Assessment

| Action | Risk Level | Justification |
|--------|------------|---------------|
| `get_all_service_status` | LOW | Read-only health check operation |
| `diagnose_service1` | LOW | Read-only diagnostic operation |
| `fix_service1` (rm -f /tmp/service.lock) | MEDIUM | Removes temporary lockfile only. Per AGENTS.md security policy, this is auto-approved as it only affects a temporary file and does not impact service data or configuration. The service is already in a failed state, so risk of further disruption is minimal. |
| `get_all_service_status` (verification) | LOW | Read-only health check operation |

**Risk Classification Rationale**: 
- The remediation action is classified as MEDIUM risk because it modifies the filesystem state
- However, it is auto-approved per repository security policy because:
  - It only removes a temporary lockfile (`/tmp/service.lock`)
  - The service is already non-functional (HTTP 500)
  - The operation is reversible (service creates lockfile on next start)
  - No data or configuration is modified

## Remediation

Executed the `fix_service1` MCP tool which remotely removed the stale lockfile.

### Tool Output 3: Fix Execution
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

**Action Details**:
- Command: `rm -f /tmp/service.lock`
- Return code: 0 (success)
- No errors encountered
- Service automatically recovered after lockfile removal

## Verification

Post-remediation status check confirmed service1 is now healthy and responding with HTTP 200.

### Tool Output 4: Post-Fix Status
```json
{
  "service1": {
    "path": "/service1",
    "http_code": "200",
    "healthy": true
  },
  "service2": {
    "path": "/service2",
    "http_code": "500",
    "healthy": false
  },
  "service3": {
    "path": "/service3",
    "http_code": "500",
    "healthy": false
  }
}
```

**Success Criteria Met**:
- ✅ `fix_service1` returned `"fixed": true`
- ✅ `fix_service1` showed `"post_http_status": "200"`
- ✅ `get_all_service_status` confirms service1 `"http_code": "200"`
- ✅ Service1 is now healthy

## Summary

Service1 was experiencing HTTP 500 errors due to a stale lockfile at `/tmp/service.lock`. The issue was successfully resolved by removing the lockfile using the `fix_service1` MCP tool. The service immediately recovered and is now responding with HTTP 200 status codes.

---

**Note**: Services 2 and 3 are still showing HTTP 500 errors and may require separate investigation and remediation.
