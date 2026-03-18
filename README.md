# OpenHands SRE Demo

Demonstrates **OpenHands Cloud** integration with **GitHub** for autonomous incident remediation.

> **For full demo instructions, see [DEMO.md](DEMO.md)**

## Real-World Incident Scenarios

The scenarios in this demo are based on [ITBench](https://github.com/itbench-hub/ITBench), a public benchmark for IT automation from IBM Research. These aren't toy examples. They represent real incident patterns that SRE teams face in production.

## What This Demo Shows

1. **GitHub Issue → Automatic Agent** — Create an issue with `openhands` label, agent picks it up
2. **MCP-Based Remediation** — Agent calls remote MCP tools to diagnose and fix live services
3. **Verified Fix** — Agent confirms the service returns HTTP 200 before documenting
4. **PR with Documentation** — Agent creates PR with diagnosis, risk assessment, and MCP tool outputs
5. **Security Policy** — Agent follows risk-level rules in `AGENTS.md` (LOW/MEDIUM auto-approved, HIGH requires human)
6. **Jenkins Add-On** — Jenkins can validate the fixed branch without replacing the GitHub + MCP flow

## OpenHands Features Highlighted

This demo showcases key OpenHands capabilities:

| Feature | How It's Used | Why It Matters |
|---------|---------------|----------------|
| **GitHub Integration** | Issues with `openhands` label auto-trigger agents | Zero-touch incident response |
| **MCP Tools** | Agent calls remote diagnose/fix tools via MCP server | Live infrastructure remediation from Cloud |
| **Skills System** | `.agents/skills/` contains runbooks with MCP tool sequences | Auditable, version-controlled remediation |
| **Security Policies** | `AGENTS.md` defines LOW/MEDIUM/HIGH risk rules | Governance at scale |
| **Branch Protection** | Agent creates PRs, can't push to main | Human stays in control |
| **Jenkins Validation** | `Jenkinsfile` runs smoke checks and integration tests after remediation | Fits existing enterprise CI controls |

### Skills: More Than Just Documentation

Skills in `.agents/skills/` can include:
- **Markdown runbooks** (`SKILL.md`) - Human-readable, auditable steps
- **Executable code** (`diagnose.py`, `remediate.py`) - Reusable, testable automation
- **Python modules** (`skill.py`) - Import and run programmatically

```
.agents/skills/stale-lockfile/
├── SKILL.md        # Runbook the agent follows
├── diagnose.py     # Executable diagnosis script
├── remediate.py    # Executable remediation script
└── skill.py        # Python module interface
```

### Security: Risk-Based Execution

The agent classifies every action by risk level:

| Risk | Examples | Agent Behavior |
|------|----------|----------------|
| **LOW** | `curl`, `cat`, health checks | Execute immediately |
| **MEDIUM** | `rm -f /tmp/file`, restart service | Execute with justification |
| **HIGH** | `rm -rf`, config changes | **STOP** and request approval |

This is defined in `AGENTS.md` - fully customizable per repository.

## Quick Start

```bash
# 1. First-time bootstrap or full demo reset
./scripts/setup_demo.sh

# 2. After a reboot / for normal day-to-day use
./scripts/start_demo.sh

# 3. Expose via Tailscale Funnel if not already configured
tailscale funnel --set-path / 15000     # demo service
tailscale funnel --set-path /mcp 8080   # MCP server

# 4. Configure OpenHands Cloud with your MCP URL:
#    https://your-machine.tailnet.ts.net/mcp

# 5. Break a service and create an issue
docker exec openhands-gepa-demo touch /tmp/service.lock
export DEMO_TARGET_URL=https://your-machine.tailnet.ts.net
uv run python scripts/create_demo_issue.py --scenario stale_lockfile

# 6. Watch OpenHands Cloud fix it live via MCP tools
#    https://app.all-hands.dev

# 7. Optional: validate the fix in Jenkins
#    - Point Jenkins at this repo
#    - Run the root Jenkinsfile
#    - Jenkins starts the local demo stack and validates the fixed state
```

### Verify MCP Pipeline

```bash
# Test agent runs diagnose → fix → verify for all broken services
uv run python scripts/test_mcp_agent.py
uv run python scripts/test_mcp_agent.py --url https://your-machine.tailnet.ts.net/mcp
```

### Setup vs Start

Use:

```bash
./scripts/setup_demo.sh
```

when you want the fuller bootstrap flow. It:
- rebuilds the target image
- rebuilds the Jenkins demo image
- stages the stale-lockfile scenario
- checks Tailscale Funnel
- attempts GitHub webhook setup when `gh` auth and Funnel are available

Use:

```bash
./scripts/start_demo.sh
```

for normal pre-demo startup and verification. It now leaves all three demo services broken by default so the browser starts in the incident state.

### After a Restart

Use a single command:

```bash
./scripts/start_demo.sh
```

This is the normal pre-demo command. It:
- recreates the demo container
- starts the MCP server
- starts the local Jenkins controller using the existing Jenkins image
- runs the full preflight, including the GitHub webhook check
- then stages `service1`, `service2`, and `service3` as broken for the live demo

If you need a clean baseline instead, use `./scripts/start_demo.sh --healthy`.

### Jenkins Add-On

Jenkins works best here as a post-remediation gate, not the incident trigger.
The recommended flow is:

1. OpenHands fixes the incident through MCP and creates the PR.
2. Jenkins checks out that branch.
3. Jenkins runs `./scripts/jenkins_verify_demo.sh`.
4. Jenkins reports that the live stack, MCP endpoint, and integration tests all passed.

The repository includes a root `Jenkinsfile` for this flow.

For a local demo controller only, start Jenkins with:

```bash
./scripts/start_jenkins_demo.sh
```

This launches a Jenkins container on `http://127.0.0.1:8081` with:
- login `admin / admin`
- Docker socket access for the demo container and tests
- this repo mounted at `/workspace/openhands-sre`

Then create a Pipeline job and use:

```text
/workspace/openhands-sre/Jenkinsfile
```

For the polished local demo, the job is precreated automatically as:

```text
OpenHands SRE Demo
```

Before running the live demo, the simplest path is:

```bash
./scripts/start_demo.sh
```

If you only want to re-check readiness without restarting anything, run the preflight directly:

```bash
./scripts/demo_preflight.sh
```

This verifies:
- Docker daemon and demo container
- host app health
- local MCP health
- public MCP health through Tailscale
- local Jenkins controller
- Jenkins demo job presence
- GitHub CLI auth and repo access
- GitHub webhook presence at `/mcp/github-webhook`

### One-Time Webhook Setup

Automatic Jenkins-on-PR requires one one-time setup step per laptop / public demo URL:

```bash
python3 scripts/setup_github_jenkins_webhook.py
```

This:
- creates `.demo_webhook_secret` if needed
- registers the repo webhook
- points GitHub at the public MCP route:

```text
https://<your-tailscale-host>/mcp/github-webhook
```

If your Tailscale Funnel hostname changes, rerun this script.

`./scripts/setup_demo.sh` now attempts this automatically when possible, but the standalone script is still the direct repair command.

### Full GitHub → OpenHands → Jenkins Demo

Run:

```bash
./scripts/run_full_github_jenkins_demo.sh
```

This does five things:
1. Starts the local Jenkins controller.
2. Runs the demo preflight.
3. Breaks `service1`.
4. Creates a labeled GitHub issue that OpenHands Cloud picks up.
5. Waits for OpenHands to create the PR.

From there, GitHub automatically sends the PR webhook to the local demo server, which triggers Jenkins.

The bridge tries to post a GitHub Check Run for the PR head SHA. If GitHub auth does not allow Check Runs, it falls back to a commit status and also comments the result on the PR.

### Jenkins Troubleshooting

Use this order:

1. Normal pre-demo command:

```bash
./scripts/start_demo.sh
```

2. If you only want a readiness check:

```bash
./scripts/demo_preflight.sh
```

If preflight fails on Docker, MCP, Jenkins, or GitHub auth:

```bash
./scripts/start_demo.sh
```

If the GitHub webhook check fails:

```bash
python3 scripts/setup_github_jenkins_webhook.py
./scripts/demo_preflight.sh
```

If Jenkins is not up:

```bash
./scripts/start_jenkins_demo.sh
curl -u admin:admin http://127.0.0.1:8081/api/json
```

If a PR exists but Jenkins does not show up on it:

```bash
gh pr view <pr-number> --json statusCheckRollup,comments,url
gh api repos/rajshah4/openhands-sre/hooks
gh api repos/rajshah4/openhands-sre/hooks/<hook-id>/deliveries
tailscale funnel status
```

What to check:
- webhook URL should be `https://<host>/mcp/github-webhook`
- latest `pull_request` delivery should return `202`
- PR should show `Jenkins / OpenHands SRE Demo`

If the Jenkins build failed:

```bash
curl -u admin:admin http://127.0.0.1:8081/job/openhands-sre-demo/lastBuild/consoleText
docker logs --tail 200 openhands-sre-jenkins
```

If the PR webhook hit GitHub but Jenkins did not start:

```bash
tail -n 200 /tmp/github_webhook_jenkins.log
```

If MCP is unhealthy locally:

```bash
curl -i http://127.0.0.1:8080/
tail -n 200 /tmp/mcp_server.log
```

If the local controller should be stopped:

```bash
./scripts/stop_jenkins_demo.sh
```

## Repository Layout

```
openhands-sre/
├── .agents/skills/           # Incident runbooks with MCP tool sequences
│   ├── stale-lockfile/       #   service1: rm lockfile
│   ├── readiness-probe-fail/ #   service2: create ready flag
│   ├── bad-env-config/       #   service3: env var fix
│   └── port-mismatch/        #   port binding issues
├── mcp_server/
│   └── server.py             # MCP server (streamable HTTP + SSE)
├── target_service/           # Docker service with breakable scenarios
├── scripts/
│   ├── setup_demo.sh         # Setup Docker + Tailscale
│   ├── create_demo_issue.py  # Create GitHub issues
│   ├── test_mcp_agent.py     # Test MCP pipeline end-to-end
│   └── fix_demo.sh           # Manual fix fallback
├── tests/                    # Integration tests
├── AGENTS.md                 # Security policy + MCP tool instructions
├── DEMO.md                   # Full demo guide
└── README.md
```

## Scenarios

| Path | Scenario | Break | MCP Fix | Manual Fix |
|------|----------|-------|---------|------------|
| `/service1` | Stale lockfile | `docker exec openhands-gepa-demo touch /tmp/service.lock` | `fix_service1` | `./scripts/fix_demo.sh service1` |
| `/service2` | Readiness probe | (broken by default) | `fix_service2` | `./scripts/fix_demo.sh service2` |
| `/service3` | Bad env config | (broken by default) | `fix_service3` (instructions) | `./scripts/fix_demo.sh service3` |

## Security Policy

The `AGENTS.md` file controls agent behavior:

| Risk Level | Action |
|------------|--------|
| **LOW** | Auto-execute (health checks, reading files) |
| **MEDIUM** | Execute with reporting (removing temp files) |
| **HIGH** | Stop and request human approval |

## Requirements

- Docker
- [GitHub CLI (`gh`)](https://cli.github.com/) - installed and authenticated
- GitHub repo connected to OpenHands Cloud
- Tailscale Funnel (for public URL exposure)
- Jenkins agent with Docker and `uv` installed (optional, for the CI add-on)

## Tests

```bash
uv run python -m unittest discover -s tests -p 'test_*.py' -v
./scripts/demo_preflight.sh
./scripts/jenkins_verify_demo.sh
./scripts/start_jenkins_demo.sh
./scripts/run_full_github_jenkins_demo.sh
```

## Acknowledgments

- Incident scenarios based on [ITBench](https://github.com/itbench-hub/ITBench) from IBM Research
- Built with [OpenHands](https://github.com/All-Hands-AI/OpenHands) - the open platform for AI software developers
