# Incident Reports

This directory contains incident reports for the OpenHands SRE demo. Each report documents a simulated or real incident, including:

- Diagnosis using MCP tools
- Risk assessment of remediation actions  
- Remediation steps executed
- Verification of the fix
- Post-incident summary

## Report Format

Each incident report follows the format defined in `AGENTS.md`:

1. **Skill Used** - The runbook/skill from `.agents/skills/` that was applied
2. **Diagnosis** - What was found (including MCP tool outputs)
3. **Risk Assessment** - Risk level of planned actions and justification
4. **Remediation** - Actions taken with MCP tool outputs
5. **Verification** - How the fix was confirmed (including post-fix MCP tool outputs)

## Naming Convention

Incident reports are named: `incident-{issue-number}-{brief-description}.md`

Example: `incident-171-service1-stale-lockfile.md`

## Purpose

These reports provide:
- Audit trail for incident response
- Documentation of MCP tool usage
- Examples for training and onboarding
- Evidence of adherence to security policies
- Historical context for similar future incidents
