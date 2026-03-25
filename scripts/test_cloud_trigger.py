#!/usr/bin/env python3
"""
Smoke test for the GitHub -> OpenHands Cloud issue trigger path.

This catches the class of failure where local infra and public MCP are healthy,
but OpenHands Cloud cannot initialize a trigger-created conversation because the
user session or integration state has expired.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from datetime import datetime, timezone


def run_cmd(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, capture_output=True, text=True, check=False)


def run_gh_json(args: list[str]) -> object:
    result = run_cmd(["gh", *args])
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "gh command failed")
    return json.loads(result.stdout)


def create_issue(repo: str) -> tuple[int, str]:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%SZ")
    title = f"[cloud-trigger-smoke] verify GitHub -> OpenHands trigger ({now})"
    body = """## Cloud Trigger Smoke Test

This disposable issue verifies that a fresh `openhands` label event can start a
new OpenHands Cloud conversation.

Expected outcome:
- OpenHands posts an \"I'm on it\" comment or equivalent progress comment.
- OpenHands does not reply with a session-expired or initialization error.
"""

    result = run_cmd(
        [
            "gh",
            "issue",
            "create",
            "--repo",
            repo,
            "--title",
            title,
            "--body",
            body,
            "--label",
            "openhands",
        ]
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "failed to create issue")

    issue_url = result.stdout.strip()
    issue = run_gh_json(
        [
            "issue",
            "view",
            issue_url,
            "--repo",
            repo,
            "--json",
            "number,url",
        ]
    )
    return int(issue["number"]), str(issue["url"])


def fetch_comments(repo: str, number: int) -> list[dict]:
    comments = run_gh_json(
        [
            "api",
            f"repos/{repo}/issues/{number}/comments",
        ]
    )
    if not isinstance(comments, list):
        raise RuntimeError("unexpected comments payload")
    return comments


def close_issue(repo: str, number: int) -> None:
    result = run_cmd(
        [
            "gh",
            "issue",
            "close",
            str(number),
            "--repo",
            repo,
            "--comment",
            "Closing disposable cloud-trigger smoke test issue.",
        ]
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "failed to close issue")


def classify_bot_comment(comment: dict) -> tuple[str, str] | None:
    user = comment.get("user") or {}
    login = str(user.get("login") or "")
    if login != "openhands-ai[bot]":
        return None

    body = str(comment.get("body") or "")
    lowered = body.lower()
    if "session has expired" in lowered:
        return ("expired", body)
    if "failed to initialize conversation" in lowered:
        return ("init_failed", body)
    if "i'm on it" in lowered or "track my progress at all-hands.dev" in lowered:
        return ("ok", body)
    return ("other", body)


def wait_for_bot(repo: str, number: int, timeout_seconds: int, poll_seconds: int) -> tuple[str, str]:
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        comments = fetch_comments(repo, number)
        for comment in comments:
            classified = classify_bot_comment(comment)
            if classified is not None:
                return classified
        time.sleep(poll_seconds)
    return ("timeout", "No OpenHands bot comment observed before timeout.")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Smoke test the GitHub issue label -> OpenHands Cloud trigger path"
    )
    parser.add_argument(
        "--repo",
        default="rajshah4/openhands-sre",
        help="GitHub repo in owner/name format",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=90,
        help="Seconds to wait for an OpenHands bot comment",
    )
    parser.add_argument(
        "--poll-interval",
        type=int,
        default=5,
        help="Seconds between comment polls",
    )
    parser.add_argument(
        "--keep-issue",
        action="store_true",
        help="Keep the disposable issue open for manual inspection",
    )
    args = parser.parse_args()

    print(f"Creating disposable smoke-test issue in {args.repo}...")
    number, url = create_issue(args.repo)
    print(f"Created issue #{number}: {url}")
    print("Waiting for OpenHands bot response...")

    exit_code = 0
    try:
        status, detail = wait_for_bot(
            args.repo,
            number,
            timeout_seconds=args.timeout,
            poll_seconds=args.poll_interval,
        )

        if status == "ok":
            print("PASS OpenHands Cloud accepted the trigger and started work.")
            print(detail)
        elif status == "expired":
            print("FAIL OpenHands Cloud reported an expired session.")
            print(detail)
            exit_code = 1
        elif status == "init_failed":
            print("FAIL OpenHands Cloud failed to initialize the conversation.")
            print(detail)
            exit_code = 1
        else:
            print(f"FAIL Trigger smoke test ended with status: {status}")
            print(detail)
            exit_code = 1
    finally:
        if args.keep_issue:
            print(f"Keeping issue #{number} open for inspection.")
        else:
            print(f"Closing disposable issue #{number}...")
            close_issue(args.repo, number)
            print("Issue closed.")

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
