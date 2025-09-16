#!/bin/bash

# myMCPs MCP Servers Test Script
# This script tests individual MCP servers to verify they work correctly

set -e

echo "🧪 Testing myMCPs MCP Servers Individual Functionality..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✅ $message${NC}"
    elif [ "$status" = "FAIL" ]; then
        echo -e "${RED}❌ $message${NC}"
    elif [ "$status" = "INFO" ]; then
        echo -e "${BLUE}ℹ️  $message${NC}"
    else
        echo -e "${YELLOW}⚠️  $message${NC}"
    fi
}

# Test MCP server initialization
test_mcp_server() {
    local server_name=$1
    local docker_image=$2
    local env_vars=$3
    local additional_args=$4
    
    echo ""
    print_status "INFO" "Testing $server_name..."
    
    # Create initialization message
    local init_message='{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "1.0.0"}}}'
    
    # Run the test
    local result
    if [ -n "$env_vars" ]; then
        result=$(echo "$init_message" | docker run --rm -i $env_vars $docker_image $additional_args 2>&1)
    else
        result=$(echo "$init_message" | docker run --rm -i $docker_image $additional_args 2>&1)
    fi
    
    # Check if we got a valid JSON response
    if echo "$result" | grep -q '"jsonrpc":"2.0"' && echo "$result" | grep -q '"result"'; then
        print_status "PASS" "$server_name responds correctly to initialization"
        
        # Extract server info
        local server_info=$(echo "$result" | grep -o '"serverInfo":[^}]*}' | head -1)
        if [ -n "$server_info" ]; then
            print_status "INFO" "Server info: $server_info"
        fi
        
        # Extract capabilities
        local capabilities=$(echo "$result" | grep -o '"capabilities":[^}]*}' | head -1)
        if [ -n "$capabilities" ]; then
            print_status "INFO" "Capabilities: $capabilities"
        fi
        
        return 0
    else
        print_status "FAIL" "$server_name failed to respond correctly"
        echo "Response: $result"
        return 1
    fi
}

# Test 1: GitHub MCP Server
echo "Test 1: GitHub MCP Server"
test_mcp_server "GitHub MCP Server" "mcp/github-mcp-server:latest" "-e GITHUB_PERSONAL_ACCESS_TOKEN=test_token"

# Test 2: Perplexity MCP Server
echo "Test 2: Perplexity MCP Server"
test_mcp_server "Perplexity MCP Server" "mcp/perplexity-ask:latest" "-e PERPLEXITY_API_KEY=test_key"

# Test 3: PostgreSQL MCP Server
echo "Test 3: PostgreSQL MCP Server"
test_mcp_server "PostgreSQL MCP Server" "mcp/postgres:latest" "" "postgresql://mymcp_user:mymcp_pass@localhost:5432/mymcp_db"

# Test 4: Test tools listing for each server
echo ""
print_status "INFO" "Testing tools listing for each server..."

test_tools_listing() {
    local server_name=$1
    local docker_image=$2
    local env_vars=$3
    local additional_args=$4
    
    echo ""
    print_status "INFO" "Testing tools listing for $server_name..."
    
    # Create tools list message
    local tools_message='{"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}}'
    
    # Run the test
    local result
    if [ -n "$env_vars" ]; then
        result=$(echo "$tools_message" | docker run --rm -i $env_vars $docker_image $additional_args 2>&1)
    else
        result=$(echo "$tools_message" | docker run --rm -i $docker_image $additional_args 2>&1)
    fi
    
    # Check if we got a valid response
    if echo "$result" | grep -q '"jsonrpc":"2.0"' && echo "$result" | grep -q '"result"'; then
        print_status "PASS" "$server_name tools listing works"
        
        # Extract tools info
        local tools_info=$(echo "$result" | grep -o '"tools":\[[^]]*\]' | head -1)
        if [ -n "$tools_info" ]; then
            print_status "INFO" "Available tools: $tools_info"
        fi
        
        return 0
    else
        print_status "WARN" "$server_name tools listing failed or returned no tools"
        echo "Response: $result"
        return 1
    fi
}

# Test tools listing for each server
test_tools_listing "GitHub MCP Server" "mcp/github-mcp-server:latest" "-e GITHUB_PERSONAL_ACCESS_TOKEN=test_token"
test_tools_listing "Perplexity MCP Server" "mcp/perplexity-ask:latest" "-e PERPLEXITY_API_KEY=test_key"
test_tools_listing "PostgreSQL MCP Server" "mcp/postgres:latest" "" "postgresql://mymcp_user:mymcp_pass@localhost:5432/mymcp_db"

# Test 5: Validate Cursor IDE configuration
echo ""
print_status "INFO" "Validating Cursor IDE configuration..."

if [ -f .cursor/mcp.json ]; then
    print_status "PASS" "Cursor MCP configuration exists"
    
    # Validate JSON syntax
    if command -v jq &> /dev/null; then
        if jq . .cursor/mcp.json > /dev/null 2>&1; then
            print_status "PASS" "Cursor MCP configuration is valid JSON"
            
            # Check if all servers are configured
            github_configured=$(jq -r '.mcpServers.github // empty' .cursor/mcp.json)
            postgres_configured=$(jq -r '.mcpServers.postgres // empty' .cursor/mcp.json)
            perplexity_configured=$(jq -r '.mcpServers.perplexity // empty' .cursor/mcp.json)
            
            if [ -n "$github_configured" ]; then
                print_status "PASS" "GitHub MCP server is configured in Cursor"
            else
                print_status "FAIL" "GitHub MCP server is not configured in Cursor"
            fi
            
            if [ -n "$postgres_configured" ]; then
                print_status "PASS" "PostgreSQL MCP server is configured in Cursor"
            else
                print_status "FAIL" "PostgreSQL MCP server is not configured in Cursor"
            fi
            
            if [ -n "$perplexity_configured" ]; then
                print_status "PASS" "Perplexity MCP server is configured in Cursor"
            else
                print_status "FAIL" "Perplexity MCP server is not configured in Cursor"
            fi
        else
            print_status "FAIL" "Cursor MCP configuration has invalid JSON syntax"
        fi
    else
        print_status "WARN" "jq not available - cannot validate JSON syntax"
    fi
else
    print_status "FAIL" "Cursor MCP configuration not found"
fi

# Test 6: Check Docker images availability
echo ""
print_status "INFO" "Checking Docker images availability..."

images=("mcp/github-mcp-server:latest" "mcp/postgres:latest" "mcp/perplexity-ask:latest")

for image in "${images[@]}"; do
    if docker image inspect "$image" > /dev/null 2>&1; then
        print_status "PASS" "Image $image is available"
        
        # Get image size
        size=$(docker image inspect "$image" --format='{{.Size}}' | numfmt --to=iec)
        print_status "INFO" "Image size: $size"
    else
        print_status "FAIL" "Image $image is not available"
    fi
done

echo ""
echo "🎯 Test Summary:"
echo "   All MCP servers are tested individually"
echo "   Cursor IDE configuration is validated"
echo "   Docker images are verified"
echo ""
echo "📚 Next Steps:"
echo "   1. Configure your API keys in .env file"
echo "   2. Copy .cursor/mcp.json to your Cursor IDE configuration"
echo "   3. Restart Cursor IDE"
echo "   4. Test MCP integration in Cursor IDE"
echo ""
echo "🔗 Repository: https://github.com/albisher/myMCPs"
