# Incident Report: Service1 HTTP 500 - Stale Lockfile

**Issue**: #168  
**Service**: service1  
**Timestamp**: 2026-06-12  
**Status**: RESOLVED

## Skill Used

**stale-lockfile** (`.agents/skills/stale-lockfile/SKILL.md`)

## Diagnosis

### Initial Status Check

**MCP Tool**: `get_all_service_status`

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

**Finding**: service1 returning HTTP 500 (unhealthy)

### Detailed Diagnosis

**MCP Tool**: `diagnose_service1`

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

**Root Cause**: Stale lockfile present at `/tmp/service.lock`, likely left behind from a previous crash or improper shutdown.

## Risk Assessment

| Action | Risk Level | Justification |
|--------|------------|---------------|
| `get_all_service_status` | LOW | Read-only health check via HTTP |
| `diagnose_service1` | LOW | Read-only check for lockfile existence |
| `rm -f /tmp/service.lock` | MEDIUM | Removes temp file only, service unaffected. Auto-approved per AGENTS.md |

**Risk Level**: MEDIUM (auto-approved — no human approval needed)

**Rationale**: The remediation involves removing a temporary lockfile in `/tmp/`. This is:
- A non-destructive operation (removes temp file only)
- Reversible (service can recreate lockfile if needed)
- Limited scope (affects only service1's startup logic)
- Not modifying production data or system configuration

Per the security policy in `AGENTS.md`, MEDIUM risk actions are auto-approved when properly documented.

## Remediation

### Action Taken

**MCP Tool**: `fix_service1`

```json
{
  "service": "service1",
  "scenario": "stale_lockfile",
  "action": "rm -f /tmp/service.lock",
  "risk_level": "MEDIUM",
  "pre_http_status": "500",
  "fixed": true,
  "post_http_status": "200",
  "command_output": {
    "returncode": 0,
    "stdout": "",
    "stderr": ""
  }
}
```

**Command Executed** (remotely via MCP server):
```bash
docker exec openhands-gepa-demo rm -f /tmp/service.lock
```

**Result**: Lockfile successfully removed, service recovered.

## Verification

### Post-Remediation Status Check

**MCP Tool**: `get_all_service_status`

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

**Verification**: ✅ service1 now returns HTTP 200 with `"status": "ok"`

### Test Results

Integration tests confirm the fix:
```bash
$ python -m unittest tests.test_integration.TargetServiceIntegrationTests.test_stale_lockfile_recovers_500_to_200
```

Test validates:
1. Service returns HTTP 500 when lockfile present
2. Service returns HTTP 200 after lockfile removal

## Summary

**Incident**: service1 returning HTTP 500 due to stale lockfile at `/tmp/service.lock`

**Resolution**: Removed stale lockfile via MCP tool `fix_service1`

**Outcome**: Service restored to healthy state (HTTP 200)

**Time to Resolution**: < 1 minute (autonomous remediation)

**Follow-up Actions**: None required. This is a known recovery scenario covered by the `stale-lockfile` skill.

## Audit Trail

All actions were executed remotely via MCP server with proper security classification:
- **Diagnosis**: LOW risk (read-only)
- **Remediation**: MEDIUM risk (auto-approved per policy)
- **Verification**: LOW risk (read-only)

This incident response followed the runbook defined in `.agents/skills/stale-lockfile/SKILL.md` and adhered to the security policy in `AGENTS.md`.
