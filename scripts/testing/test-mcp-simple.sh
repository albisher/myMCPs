#!/bin/bash

# Simple MCP Services Test - Production Ready
set -e

echo "=========================================="
echo "Simple MCP Services Test"
echo "=========================================="

# Test GitHub MCP
echo "Testing GitHub MCP..."
if echo '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "1.0.0"}}}' | docker run -i --rm -e GITHUB_PERSONAL_ACCESS_TOKEN=your_github_token_here mcp/github-mcp-server:latest | grep -q "result"; then
    echo "✓ GitHub MCP working"
else
    echo "✗ GitHub MCP failed"
fi

# Test PostgreSQL MCP
echo "Testing PostgreSQL MCP..."
if echo '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "1.0.0"}}}' | docker run -i --rm -e POSTGRES_HOST=localhost -e POSTGRES_PORT=5432 -e POSTGRES_DB=tawreed_db -e POSTGRES_USER=tawreed_user -e POSTGRES_PASSWORD=tawreed_pass mcp/postgres:latest postgresql://tawreed_user:tawreed_pass@localhost:5432/tawreed_db | grep -q "result"; then
    echo "✓ PostgreSQL MCP working"
else
    echo "✗ PostgreSQL MCP failed"
fi

# Test Perplexity MCP
echo "Testing Perplexity MCP..."
if echo '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "1.0.0"}}}' | docker run -i --rm -e PERPLEXITY_API_KEY=your_perplexity_api_key_here mcp/perplexity-ask:latest | grep -q "result"; then
    echo "✓ Perplexity MCP working"
else
    echo "✗ Perplexity MCP failed"
fi

echo "=========================================="
echo "Simple Test Complete"
echo "=========================================="
