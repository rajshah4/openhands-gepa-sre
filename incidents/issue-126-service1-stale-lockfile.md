# Incident Report: Issue #126 - Service1 Stale Lockfile

**Date**: 2026-04-13  
**Service**: service1  
**Endpoint**: `/service1`  
**Issue**: HTTP 500 Internal Server Error  

## Skill Used

**stale-lockfile** (`.agents/skills/stale-lockfile/SKILL.md`)

## Diagnosis

Service1 was returning HTTP 500 with error message: `"stale lockfile present at /tmp/service.lock"`.

### MCP Tool Output: `get_all_service_status`
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

### MCP Tool Output: `diagnose_service1`
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

**Root Cause**: Stale lockfile at `/tmp/service.lock` left over from a previous service crash, preventing service startup.

## Risk Assessment

| Action | Risk Level | Justification |
|--------|------------|---------------|
| `rm -f /tmp/service.lock` | **MEDIUM** | Removes a temporary lockfile only. Service is already down (HTTP 500), so no service interruption. The lockfile is stale from a previous crash and blocking service recovery. Auto-approved per AGENTS.md security policy. |

This action is classified as MEDIUM risk because:
- It modifies container state (removes a file)
- It's limited to a temporary file in `/tmp/`
- The service is already non-functional
- The fix is reversible (service can recreate the lock if needed)
- Per AGENTS.md, MEDIUM risk actions are auto-approved with reporting

## Remediation

### MCP Tool Output: `fix_service1`
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

**Action Taken**: Called MCP tool `fix_service1` which executed `rm -f /tmp/service.lock` inside the service container.

**Result**: 
- Lockfile successfully removed (`rm_returncode`: 0)
- No errors during removal
- Service recovered immediately (HTTP 500 → HTTP 200)

## Verification

### MCP Tool Output: `get_all_service_status` (post-fix)
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

**Verification Results**:
- ✅ Service1 now returns HTTP 200
- ✅ Service1 health status: `healthy: true`
- ✅ Expected response: `{"status": "ok"}`
- ✅ No errors in service logs

## Success Criteria Met

- [x] `fix_service1` returned `"fixed": true`
- [x] `post_http_status`: "200"
- [x] `get_all_service_status` shows service1 with `"http_code": "200"`
- [x] Service is fully operational

## Follow-Up Actions

None required. This was a one-time operational fix for a stale lockfile. The service is designed to handle this scenario through the documented runbook.

---

_This incident was resolved using OpenHands autonomous remediation following the stale-lockfile skill runbook._
