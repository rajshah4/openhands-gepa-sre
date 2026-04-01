# KAN-8: Service1 Stale Lockfile Remediation

## Skill Used

`stale-lockfile` — `.agents/skills/stale-lockfile/SKILL.md`

## Diagnosis

Service1 (`/service1`) was returning HTTP 500. Initial status check confirmed the failure, and `diagnose_service1` identified a stale lockfile at `/tmp/service.lock` as the root cause.

**`get_all_service_status` output (before fix):**
```json
{
  "service1": { "path": "/service1", "http_code": "500", "healthy": false },
  "service2": { "path": "/service2", "http_code": "500", "healthy": false },
  "service3": { "path": "/service3", "http_code": "500", "healthy": false }
}
```

**`diagnose_service1` output:**
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
| `get_all_service_status` | LOW | Read-only health check |
| `diagnose_service1` | LOW | Read-only diagnostic — checks file existence and HTTP status |
| `fix_service1` (`rm -f /tmp/service.lock`) | MEDIUM | Removes a temporary lockfile only; does not affect application code or persistent data. Auto-approved per AGENTS.md. |
| `get_all_service_status` (verification) | LOW | Read-only health check |

## Remediation

Called `fix_service1` to remove the stale lockfile at `/tmp/service.lock`.

**`fix_service1` output:**
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

After the fix, `get_all_service_status` confirmed service1 is healthy and returning HTTP 200.

**`get_all_service_status` output (after fix):**
```json
{
  "service1": { "path": "/service1", "http_code": "200", "healthy": true },
  "service2": { "path": "/service2", "http_code": "500", "healthy": false },
  "service3": { "path": "/service3", "http_code": "500", "healthy": false }
}
```

**Result**: ✅ Service1 restored to healthy state (HTTP 200).
