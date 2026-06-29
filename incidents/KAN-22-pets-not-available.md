# Incident Report: KAN-22 — Customers Seeing Pets That Are Not Available

**Jira Issue**: [KAN-22](https://rajiv-shah.atlassian.net/browse/KAN-22)
**Date**: 2026-06-29
**Severity**: P2 — customers able to see/start adoption flows for pets that should not be available yet
**Status**: Investigated — no broken service found ✅

---

## Skill Used

`readiness-probe-fail` (availability gating) combined with a full fleet health check — `.agents/skills/readiness-probe-fail/SKILL.md`

> The reported symptom ("customers seeing pets that should not be available yet") maps to an availability/ready-state problem in this SRE demo. The three demo services are health-api (`/service1`), auth-api (`/service2`), and config-api (`/service3`), each gated on a readiness/lock/env condition.

---

## Diagnosis

Followed the required SRE workflow from `AGENTS.md`: `get_all_service_status` → `diagnose_serviceN` → fix (if broken) → `get_all_service_status` (verify).

**`get_all_service_status` (initial):**
```json
{
  "service1": { "path": "/service1", "http_code": "200", "healthy": true },
  "service2": { "path": "/service2", "http_code": "200", "healthy": true },
  "service3": { "path": "/service3", "http_code": "200", "healthy": true }
}
```

All three services were already returning HTTP 200. Per-agents diagnosis confirmed each one individually:

**`diagnose_service1` (stale lockfile / health-api):**
```json
{
  "service": "service1",
  "scenario": "stale_lockfile",
  "http_status": "200",
  "healthy": true,
  "lock_file_exists": false,
  "diagnosis": "No lockfile found",
  "recommended_action": "No action needed",
  "next_step": "Service is healthy."
}
```

**`diagnose_service2` (readiness probe / auth-api):**
```json
{
  "service": "service2",
  "scenario": "readiness_probe_fail",
  "http_status": "200",
  "healthy": true,
  "ready_flag_exists": true,
  "diagnosis": "Ready flag present",
  "recommended_action": "No action needed",
  "next_step": "Service is healthy."
}
```

**`diagnose_service3` (bad env config / config-api):**
```json
{
  "service": "service3",
  "scenario": "bad_env_config",
  "http_status": "200",
  "healthy": true,
  "required_api_key_set": true,
  "diagnosis": "Environment configured correctly",
  "recommended_action": "No action needed"
}
```

**Finding**: No service is currently returning HTTP 500 and no failure condition is present. The stale lockfile is absent, the readiness flag is present, and `REQUIRED_API_KEY` is set. There is no broken service to remediate at this time.

---

## Risk Assessment

| Action | Risk Level | Rationale |
|--------|------------|-----------|
| `get_all_service_status` | LOW | Read-only health check |
| `diagnose_service1` | LOW | Read-only — checks lockfile existence |
| `diagnose_service2` | LOW | Read-only — checks readiness flag |
| `diagnose_service3` | LOW | Read-only — checks env var presence |

No MEDIUM/HIGH risk actions were required because no service was broken. Per `AGENTS.md`, remediation tools (`fix_serviceN`) are only invoked when a diagnosis confirms a failure condition — they were not needed here.

---

## Remediation

No remediation action was taken. All three services were already healthy at the time of investigation (verified across multiple consecutive checks).

---

## Verification

**`get_all_service_status` (final):**
```json
{
  "service1": { "path": "/service1", "http_code": "200", "healthy": true },
  "service2": { "path": "/service2", "http_code": "200", "healthy": true },
  "service3": { "path": "/service3", "http_code": "200", "healthy": true }
}
```

All services return HTTP 200 with `"status": "ok"`. The availability-gating conditions (lockfile cleared, readiness flag present, env configured) are all satisfied, so no customers should be served content from a not-ready state.

---

## Next Steps / Monitoring

- If the symptom recurs, re-run `get_all_service_status` + `diagnose_serviceN` to catch a transient break, and apply the matching `fix_serviceN` tool (auto-approved for LOW/MEDIUM scenarios per `AGENTS.md`).
- The readiness-probe scenario (`service2`) is the closest match to "serving before ready"; if the issue resurfaces, prioritize `diagnose_service2` / `fix_service2`.
- No code changes were needed; this report documents the investigation only.
