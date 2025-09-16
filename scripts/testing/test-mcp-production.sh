#!/bin/bash

# Production MCP Services Test Script
# No workarounds, clean implementation

set -e

echo "=========================================="
echo "MCP Services Production Test"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test 1: Environment Configuration
echo -e "${BLUE}1. Environment Configuration${NC}"
if [ -f ".env" ]; then
    echo -e "${GREEN}✓ .env file exists${NC}"
    source .env
    if [ -n "$GITHUB_PERSONAL_ACCESS_TOKEN" ] && [ "$GITHUB_PERSONAL_ACCESS_TOKEN" != "your_github_token_here" ]; then
        echo -e "${GREEN}✓ GitHub token configured${NC}"
    else
        echo -e "${RED}✗ GitHub token not configured${NC}"
    fi
    if [ -n "$PERPLEXITY_API_KEY" ] && [ "$PERPLEXITY_API_KEY" != "your_perplexity_api_key_here" ]; then
        echo -e "${GREEN}✓ Perplexity API key configured${NC}"
    else
        echo -e "${RED}✗ Perplexity API key not configured${NC}"
    fi
else
    echo -e "${RED}✗ .env file not found${NC}"
fi

# Test 2: Network Connectivity
echo -e "${BLUE}2. Network Connectivity${NC}"
if ping -c 1 api.github.com >/dev/null 2>&1; then
    echo -e "${GREEN}✓ GitHub API accessible${NC}"
else
    echo -e "${RED}✗ GitHub API not accessible${NC}"
fi

if ping -c 1 api.perplexity.ai >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Perplexity API accessible${NC}"
else
    echo -e "${RED}✗ Perplexity API not accessible${NC}"
fi

# Test 3: Database Connection
echo -e "${BLUE}3. Database Connection${NC}"
if command -v psql >/dev/null 2>&1; then
    if PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 1;" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Database connection working${NC}"
    else
        echo -e "${RED}✗ Database connection failed${NC}"
    fi
else
    echo -e "${YELLOW}⚠ psql not available, skipping database test${NC}"
fi

# Test 4: Docker Images
echo -e "${BLUE}4. Docker Images${NC}"
if docker image inspect mcp/github-mcp-server:latest >/dev/null 2>&1; then
    echo -e "${GREEN}✓ GitHub MCP image available${NC}"
else
    echo -e "${RED}✗ GitHub MCP image not available${NC}"
fi

if docker image inspect mcp/postgres:latest >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PostgreSQL MCP image available${NC}"
else
    echo -e "${RED}✗ PostgreSQL MCP image not available${NC}"
fi

if docker image inspect mcp/perplexity-ask:latest >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Perplexity MCP image available${NC}"
else
    echo -e "${RED}✗ Perplexity MCP image not available${NC}"
fi

# Test 5: MCP Configuration
echo -e "${BLUE}5. MCP Configuration${NC}"
if [ -f ".cursor/mcp.json" ]; then
    echo -e "${GREEN}✓ MCP configuration file exists${NC}"
    if grep -q "github" .cursor/mcp.json; then
        echo -e "${GREEN}✓ GitHub MCP configured${NC}"
    else
        echo -e "${RED}✗ GitHub MCP not configured${NC}"
    fi
    if grep -q "postgres" .cursor/mcp.json; then
        echo -e "${GREEN}✓ PostgreSQL MCP configured${NC}"
    else
        echo -e "${RED}✗ PostgreSQL MCP not configured${NC}"
    fi
    if grep -q "perplexity" .cursor/mcp.json; then
        echo -e "${GREEN}✓ Perplexity MCP configured${NC}"
    else
        echo -e "${RED}✗ Perplexity MCP not configured${NC}"
    fi
else
    echo -e "${RED}✗ MCP configuration file not found${NC}"
fi

# Test 6: Direct API Tests
echo -e "${BLUE}6. Direct API Tests${NC}"

# GitHub API Test
if [ -n "$GITHUB_PERSONAL_ACCESS_TOKEN" ] && [ "$GITHUB_PERSONAL_ACCESS_TOKEN" != "your_github_token_here" ]; then
    if curl -s -H "Authorization: token $GITHUB_PERSONAL_ACCESS_TOKEN" https://api.github.com/user | grep -q "login"; then
        echo -e "${GREEN}✓ GitHub API authentication working${NC}"
    else
        echo -e "${RED}✗ GitHub API authentication failed${NC}"
    fi
else
    echo -e "${YELLOW}⚠ GitHub token not configured, skipping API test${NC}"
fi

# Perplexity API Test
if [ -n "$PERPLEXITY_API_KEY" ] && [ "$PERPLEXITY_API_KEY" != "your_perplexity_api_key_here" ]; then
    if curl -s -X POST "https://api.perplexity.ai/chat/completions" \
        -H "Authorization: Bearer $PERPLEXITY_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{"model": "llama-3.1-sonar-small-128k-online", "messages": [{"role": "user", "content": "Hello"}], "max_tokens": 10}' | grep -q "choices"; then
        echo -e "${GREEN}✓ Perplexity API authentication working${NC}"
    else
        echo -e "${RED}✗ Perplexity API authentication failed${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Perplexity API key not configured, skipping API test${NC}"
fi

echo "=========================================="
echo "Production Test Complete"
echo "=========================================="
