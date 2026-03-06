#!/bin/bash
# Run this before each demo to break services and clear logs

echo "🔧 Breaking services..."
docker exec openhands-gepa-demo touch /tmp/service.lock
docker exec openhands-gepa-demo rm -f /tmp/ready.flag
> /tmp/mcp_server.log

echo ""
echo "Service status:"
echo "  service1: $(curl -s http://127.0.0.1:15000/service1 | python3 -c 'import sys,json; print(json.load(sys.stdin).get("status","?"))' 2>/dev/null)"
echo "  service2: $(curl -s http://127.0.0.1:15000/service2 | python3 -c 'import sys,json; print(json.load(sys.stdin).get("status","?"))' 2>/dev/null)"
echo "  service3: $(curl -s http://127.0.0.1:15000/service3 | python3 -c 'import sys,json; print(json.load(sys.stdin).get("status","?"))' 2>/dev/null)"

echo ""
echo "✅ Ready. Create an issue with the 'openhands' label to start."
echo ""
echo "Watch MCP calls:  tail -f /tmp/mcp_server.log | grep 'TOOL CALLED'"
