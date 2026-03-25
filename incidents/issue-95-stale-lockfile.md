# Incident Report: Issue #95 - Service1 Stale Lockfile

- **Date**: 2026-03-23
- **Service**: `/service1`
- **Symptom**: HTTP 500 with stale lockfile at `/tmp/service.lock`
- **Skill Used**: `stale-lockfile`

## Summary
Service1 returned HTTP 500 because a stale lockfile was present. The lockfile was removed via MCP remediation and the service returned HTTP 200. Services 2 and 3 were still unhealthy after the fix and were not part of this incident scope.

## MCP Tool Outputs

### 1) `get_all_service_status`
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

### 2) `diagnose_service1`
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

### 3) `fix_service1`
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

### 4) `get_all_service_status` (verification)
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
