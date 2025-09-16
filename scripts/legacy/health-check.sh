#!/bin/bash

# myMCPs Health Check Script
# This script monitors the health of MCP servers

set -e

echo "🔍 Checking myMCPs MCP Servers Health..."

# Function to check service health
check_service() {
    local service_name=$1
    local port=$2
    local container_name=$3
    
    echo -n "Checking $service_name... "
    
    # Check if container is running
    if docker ps --format "table {{.Names}}" | grep -q "^${container_name}$"; then
        echo -n "Container: ✅ "
        
        # Check if port is accessible
        if curl -s -f "http://localhost:${port}" > /dev/null 2>&1; then
            echo "Port: ✅"
        else
            echo "Port: ❌ (not accessible)"
        fi
    else
        echo "Container: ❌ (not running)"
    fi
}

# Check each service
check_service "GitHub MCP Server" "8081" "mymcp-github"
check_service "PostgreSQL MCP Server" "8082" "mymcp-postgres"
check_service "Perplexity MCP Server" "8083" "mymcp-perplexity"

echo ""
echo "📊 Docker Compose Status:"
docker-compose ps

echo ""
echo "📈 Resource Usage:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" | grep mymcp

echo ""
echo "📝 Recent Logs (last 10 lines per service):"
echo "--- GitHub MCP Server ---"
docker logs --tail 10 mymcp-github 2>/dev/null || echo "No logs available"

echo ""
echo "--- PostgreSQL MCP Server ---"
docker logs --tail 10 mymcp-postgres 2>/dev/null || echo "No logs available"

echo ""
echo "--- Perplexity MCP Server ---"
docker logs --tail 10 mymcp-perplexity 2>/dev/null || echo "No logs available"
