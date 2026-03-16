#!/usr/bin/env python3
"""
Create or update the GitHub webhook that triggers local Jenkins for every PR.

The webhook points at the public MCP host's /github-webhook endpoint.
"""

from __future__ import annotations

import argparse
import json
import os
import secrets
import subprocess
import sys
from urllib.parse import urlparse


def run_gh(args: list[str], stdin: str | None = None) -> str:
    result = subprocess.run(
        ["gh", *args],
        input=stdin,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "gh command failed")
    return result.stdout


def infer_base_url(public_mcp_url: str) -> str:
    parsed = urlparse(public_mcp_url)
    if not parsed.scheme or not parsed.netloc:
        raise ValueError(f"Invalid PUBLIC_MCP_URL: {public_mcp_url}")
    path = parsed.path.rstrip("/")
    return f"{parsed.scheme}://{parsed.netloc}{path}"


def main() -> int:
    parser = argparse.ArgumentParser(description="Configure GitHub webhook for Jenkins PR validation")
    parser.add_argument("--repo", default=os.getenv("GITHUB_REPO", "rajshah4/openhands-sre"))
    parser.add_argument("--public-mcp-url", default=os.getenv("PUBLIC_MCP_URL", "https://macbook-pro.tail21d104.ts.net/mcp"))
    parser.add_argument("--secret", default=os.getenv("GITHUB_WEBHOOK_SECRET"))
    parser.add_argument("--webhook-url", default=os.getenv("GITHUB_WEBHOOK_URL"))
    parser.add_argument("--secret-file", default=os.getenv("WEBHOOK_SECRET_FILE", ".demo_webhook_secret"))
    args = parser.parse_args()

    secret = args.secret
    if not secret and os.path.exists(args.secret_file):
        with open(args.secret_file, "r", encoding="utf-8") as handle:
            secret = handle.read().strip()
    if not secret:
        secret = secrets.token_hex(32)
        with open(args.secret_file, "w", encoding="utf-8") as handle:
            handle.write(secret + "\n")
        print(f"Created webhook secret file: {args.secret_file}")

    webhook_url = args.webhook_url or f"{infer_base_url(args.public_mcp_url)}/github-webhook"
    hooks = json.loads(run_gh(["api", f"repos/{args.repo}/hooks"]))

    existing = None
    for hook in hooks:
        if hook.get("config", {}).get("url") == webhook_url:
            existing = hook
            break

    payload = {
        "name": "web",
        "active": True,
        "events": ["pull_request"],
        "config": {
            "url": webhook_url,
            "content_type": "json",
            "secret": secret,
            "insecure_ssl": "0",
        },
    }

    if existing:
        hook_id = existing["id"]
        run_gh(["api", "--method", "PATCH", f"repos/{args.repo}/hooks/{hook_id}", "--input", "-"], json.dumps(payload))
        print(f"Updated webhook {hook_id} -> {webhook_url}")
    else:
        run_gh(["api", "--method", "POST", f"repos/{args.repo}/hooks", "--input", "-"], json.dumps(payload))
        print(f"Created webhook -> {webhook_url}")

    print("Webhook events: pull_request")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
