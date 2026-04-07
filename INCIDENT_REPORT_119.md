# Incident Report: Issue #119 - Service1 Stale Lockfile

## Skill Used
**stale-lockfile** (`.agents/skills/stale-lockfile/SKILL.md`)

## Diagnosis

Service1 was returning HTTP 500 Internal Server Error due to a stale lockfile remaining after a previous crash.

### Initial Status Check
```json
{
  "service1": {
    "path": "/service1",
    "http_code": "500",
    "healthy": false
  }
}
```

### Diagnostic Results
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

**Root Cause**: Stale lockfile present at `/tmp/service.lock` preventing service startup.

## Risk Assessment

| Action | Risk Level | Justification |
|--------|------------|---------------|
| `rm -f /tmp/service.lock` | **MEDIUM** | Removes temporary lockfile only. Service unaffected. Auto-approved per AGENTS.md policy. |

**Rationale**: The lockfile is a temporary file used for process synchronization. Removing it is safe because:
- It's in `/tmp/` (temporary directory)
- The file is stale (from a crashed process)
- The service cannot start while the file exists
- Removal is reversible (service recreates it when needed)

## Remediation

**Action Taken**: Executed `fix_service1` MCP tool to remove stale lockfile.

### Remediation Output
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

**Result**: ✅ Successfully removed lockfile with return code 0 (no errors).

## Verification

### Post-Fix Status Check
```json
{
  "service1": {
    "path": "/service1",
    "http_code": "200",
    "healthy": true
  }
}
```

**Verification Results**:
- ✅ Service1 now returns HTTP 200
- ✅ Health check passes with `"healthy": true`
- ✅ Service responding correctly to requests
- ✅ No errors in the remediation process

## Summary

Successfully resolved HTTP 500 error on service1 by removing stale lockfile at `/tmp/service.lock`. Service is now healthy and returning expected HTTP 200 responses. Remediation was performed using MCP tools with MEDIUM risk level (auto-approved).

**Time to Resolution**: < 1 minute  
**Service Downtime**: Minimal (lockfile removal is instantaneous)  
**Impact**: Service restored to full health
