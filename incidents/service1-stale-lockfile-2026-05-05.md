# Incident Report: Service1 Stale Lockfile - 2026-05-05

**Date**: 2026-05-05  
**Reporter**: KAN-8  
**Service**: service1  
**Status**: ✅ RESOLVED

---

## Skill Used

**Skill**: `stale-lockfile` (`.agents/skills/stale-lockfile/SKILL.md`)

---

## Diagnosis

### Initial Status Check

**Tool**: `get_all_service_status`

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

**Finding**: service1 returning HTTP 500, while service2 and service3 are healthy.

### Root Cause Analysis

**Tool**: `diagnose_service1`

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

**Root Cause**: Stale lockfile at `/tmp/service.lock` preventing service1 from starting properly.

---

## Risk Assessment

| Action | Risk Level | Justification |
|--------|------------|---------------|
| `get_all_service_status` | LOW | Read-only health check, no modifications |
| `diagnose_service1` | LOW | Read-only diagnostic check for lockfile presence |
| `rm -f /tmp/service.lock` | MEDIUM | Removes temporary lockfile only. Auto-approved per AGENTS.md stale-lockfile runbook. Service unaffected as lockfile is only a startup guard. |
| `get_all_service_status` (verification) | LOW | Read-only health check to confirm resolution |

**Overall Risk**: MEDIUM (auto-approved - no human approval required per repository security policy)

---

## Remediation

### Action Taken

**Tool**: `fix_service1`  
**Command Executed**: `rm -f /tmp/service.lock`

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

**Result**: 
- Lockfile successfully removed (return code: 0)
- Service immediately recovered
- HTTP status changed from 500 → 200

---

## Verification

### Post-Fix Status Check

**Tool**: `get_all_service_status`

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

**Success Criteria Met**:
- ✅ `fix_service1` returned `"fixed": true`
- ✅ `fix_service1` returned `"post_http_status": "200"`
- ✅ `get_all_service_status` shows service1 with `"http_code": "200"`
- ✅ service1 status changed from `"healthy": false` to `"healthy": true`

---

## Timeline

| Time | Event |
|------|-------|
| Initial | service1 returning HTTP 500 |
| +0:00 | Status check confirmed service1 failure |
| +0:01 | Diagnosis identified stale lockfile |
| +0:02 | Lockfile removed via `fix_service1` |
| +0:03 | Verification confirmed service1 healthy (HTTP 200) |

**Total Time to Resolution**: ~3 seconds

---

## Lessons Learned

### What Went Well
- Automated MCP tools enabled rapid diagnosis and remediation
- Clear runbook in `.agents/skills/stale-lockfile/` provided step-by-step guidance
- Risk assessment allowed auto-approval without human intervention
- Immediate verification confirmed successful resolution

### What Could Be Improved
- Consider implementing automatic stale lockfile cleanup on service restart
- Add monitoring/alerting for lockfile age to prevent future occurrences
- Document common crash scenarios that lead to stale lockfiles

### Preventive Measures
- Review service shutdown procedures to ensure proper lockfile cleanup
- Implement lockfile TTL or automatic cleanup on process start
- Add health check that detects stale lockfiles before they cause 500 errors

---

## References

- **Runbook**: `.agents/skills/stale-lockfile/SKILL.md`
- **Security Policy**: `AGENTS.md` - MEDIUM risk auto-approval
- **Issue**: KAN-8
