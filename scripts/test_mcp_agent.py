#!/usr/bin/env python3
"""
Test agent that connects to the MCP server and runs the full
diagnose → fix → verify cycle for each broken service.

Usage:
    # Local
    uv run python scripts/test_mcp_agent.py

    # Through Tailscale Funnel (same path OpenHands Cloud uses)
    uv run python scripts/test_mcp_agent.py --url https://macbook-pro.tail21d104.ts.net/mcp

    # SSE transport instead of streamable HTTP
    uv run python scripts/test_mcp_agent.py --transport sse --url http://127.0.0.1:8080/sse
"""

import argparse
import asyncio
import json
import sys

from mcp import ClientSession


async def run_agent(url: str, transport: str):
    print(f"🔌 Connecting to MCP server: {url} (transport: {transport})")
    print()

    if transport == "http":
        from mcp.client.streamable_http import streamablehttp_client
        cm = streamablehttp_client(url)
    else:
        from mcp.client.sse import sse_client
        cm = sse_client(url)

    async with cm as streams:
        read, write = streams[0], streams[1]
        async with ClientSession(read, write) as session:
            await session.initialize()

            # 1. List tools
            tools = await session.list_tools()
            tool_names = [t.name for t in tools.tools]
            print(f"✅ Connected — {len(tool_names)} tools available:")
            for t in tools.tools:
                desc = (t.description or "").split("\n")[0][:70]
                print(f"   • {t.name}: {desc}")
            print()

            # 2. Get status of all services
            print("=" * 60)
            print("STEP 1: get_all_service_status")
            print("=" * 60)
            result = await session.call_tool("get_all_service_status", {})
            status = json.loads(result.content[0].text)
            for svc, info in status.items():
                icon = "✅" if info["healthy"] else "❌"
                print(f"  {icon} {svc}: HTTP {info['http_code']}")
            print()

            broken = [s for s, i in status.items() if not i["healthy"]]
            if not broken:
                print("🎉 All services healthy — nothing to fix!")
                return True

            # 3. For each broken service: diagnose → fix → verify
            all_fixed = True
            for svc in broken:
                num = svc.replace("service", "")
                diag_tool = f"diagnose_service{num}"
                fix_tool = f"fix_service{num}"

                print("=" * 60)
                print(f"STEP 2: {diag_tool}")
                print("=" * 60)
                result = await session.call_tool(diag_tool, {})
                diag = json.loads(result.content[0].text)
                print(f"  Scenario:    {diag.get('scenario')}")
                print(f"  HTTP status: {diag.get('http_status')}")
                print(f"  Diagnosis:   {diag.get('diagnosis')}")
                print(f"  Next step:   {diag.get('next_step', diag.get('recommended_action'))}")
                print()

                if fix_tool not in tool_names:
                    print(f"  ⚠️  {fix_tool} not available, skipping")
                    all_fixed = False
                    continue

                print("=" * 60)
                print(f"STEP 3: {fix_tool}")
                print("=" * 60)
                result = await session.call_tool(fix_tool, {})
                fix = json.loads(result.content[0].text)
                fixed = fix.get("fixed", False)
                icon = "✅" if fixed else "❌"
                print(f"  {icon} fixed={fixed}")
                print(f"  Action:      {fix.get('action')}")
                print(f"  Risk:        {fix.get('risk_level')}")
                print(f"  Pre-status:  {fix.get('pre_http_status')}")
                print(f"  Post-status: {fix.get('post_http_status')}")
                if not fixed:
                    all_fixed = False
                print()

            # 4. Final verification
            print("=" * 60)
            print("STEP 4: get_all_service_status (verification)")
            print("=" * 60)
            result = await session.call_tool("get_all_service_status", {})
            status = json.loads(result.content[0].text)
            for svc, info in status.items():
                icon = "✅" if info["healthy"] else "❌"
                print(f"  {icon} {svc}: HTTP {info['http_code']}")
            print()

            if all_fixed:
                print("🎉 All broken services remediated!")
            else:
                print("⚠️  Some services still need attention.")
            return all_fixed


def main():
    parser = argparse.ArgumentParser(description="Test MCP agent — diagnose/fix/verify cycle")
    parser.add_argument("--url", default="http://127.0.0.1:8080/mcp",
                        help="MCP server URL (default: local streamable HTTP)")
    parser.add_argument("--transport", choices=["http", "sse"], default="http",
                        help="MCP transport (default: http)")
    args = parser.parse_args()

    ok = asyncio.run(run_agent(args.url, args.transport))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
