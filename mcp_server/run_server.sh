#!/bin/bash
# Run the MCP server for OpenHands SRE Demo
# 
# This exposes the server on port 8080 for OpenHands Cloud to connect.
# Use with Tailscale Funnel: tailscale funnel 8080

cd "$(dirname "$0")/.."
uv run python mcp_server/server.py
