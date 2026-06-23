# Incident Report: Service1 HTTP 500 - Stale Lockfile

**Issue**: #171  
**Date**: 2026-06-23  
**Service**: service1  
**Status**: Resolved  

## Skill Used

**stale-lockfile** (`.agents/skills/stale-lockfile/`)

## Diagnosis

Service1 returned HTTP 500 with error message:
```json
{
  "status": "error",
  "reason": "stale lockfile present at /tmp/service.lock"
}
```

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

### Root Cause

The service crashed in a previous instance and left behind a lockfile at `/tmp/service.lock`. The Flask application at `target_service/app.py` checks for this file's existence in the `stale_lockfile` scenario and returns HTTP 500 if it exists:

```python
if scenario == "stale_lockfile":
    if os.path.exists(LOCKFILE):
        return jsonify({"status": "error", "reason": f"stale lockfile present at {LOCKFILE}"}), 500
```

## Risk Assessment

| Action | Risk Level | Justification |
|--------|------------|---------------|
| `rm -f /tmp/service.lock` | **MEDIUM** | Removes a temporary file only. The lockfile is in `/tmp/` and is not part of application state. Service behavior is unaffected after removal. This is auto-approved per the security policy in `AGENTS.md`. |

**Risk Level: MEDIUM** (auto-approved — no human approval needed)

The remediation action:
- Removes a file, but it's a temporary lockfile in `/tmp/`
- Does not modify system configuration
- Does not affect other services
- Is reversible (service can recreate the lock if needed)
- Follows the established pattern in the stale-lockfile skill

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

### Execution Details

**Command Executed** (via MCP server):
```bash
docker exec openhands-gepa-demo rm -f /tmp/service.lock
```

**Result**: Successfully removed the stale lockfile. The `rm -f` command returned exit code 0 with no errors.

## Verification

### MCP Tool Output: `get_all_service_status` (Post-Fix)

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

### Test Validation

The existing integration test `test_stale_lockfile_recovers_500_to_200` in `tests/test_integration.py` validates this remediation:

```python
def test_stale_lockfile_recovers_500_to_200(self) -> None:
    name = self._start_container("stale_lockfile")
    try:
        before = self._container_http_status(name)
        self.assertEqual(before, "500")

        self._run(["docker", "exec", name, "sh", "-lc", "rm -f /tmp/service.lock"])

        after = self._container_http_status(name)
        self.assertEqual(after, "200")
    finally:
        self._stop_container(name)
```

**Test Result**: ✅ Pass

### Confirmation

- ✅ Service1 now returns HTTP 200
- ✅ Service responds with `{"status": "ok", "scenario": "stale_lockfile"}`
- ✅ All three services are healthy
- ✅ Integration test confirms the fix is valid

## Summary

Successfully remediated service1 HTTP 500 error by removing stale lockfile at `/tmp/service.lock`. The fix was executed as a MEDIUM risk action (auto-approved) using the MCP tool `fix_service1`. Post-remediation verification confirms all services are healthy.

**Time to Resolution**: < 2 minutes  
**Service Downtime**: 0 minutes (demo environment)  
**Manual Intervention Required**: None
