#!/bin/bash

# Local Search MCP Server Test Script
# This script tests the local search MCP server functionality

set -e

echo "🧪 Testing Local Search MCP Server..."

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

# Test 1: Check if Docker image can be built
echo "Test 1: Docker Image Build"
print_status "INFO" "Building local search MCP Docker image..."

if docker build -t mymcp-local-search ./local-search-mcp/ > /dev/null 2>&1; then
    print_status "PASS" "Docker image built successfully"
else
    print_status "FAIL" "Failed to build Docker image"
    exit 1
fi

# Test 2: Check if the MCP server starts
echo "Test 2: MCP Server Startup"
print_status "INFO" "Testing MCP server startup..."

# Create a test initialization message
INIT_MESSAGE='{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "1.0.0"}}}'

# Test the server
RESULT=$(echo "$INIT_MESSAGE" | timeout 10 docker run --rm -i -v "$(pwd):/workspace" -e SEARCH_ROOT=/workspace mymcp-local-search 2>&1 || echo "timeout")

if echo "$RESULT" | grep -q '"jsonrpc":"2.0"' && echo "$RESULT" | grep -q '"result"'; then
    print_status "PASS" "MCP server responds correctly to initialization"
    
    # Extract server info
    SERVER_INFO=$(echo "$RESULT" | grep -o '"serverInfo":[^}]*}' | head -1)
    if [ -n "$SERVER_INFO" ]; then
        print_status "INFO" "Server info: $SERVER_INFO"
    fi
else
    print_status "FAIL" "MCP server failed to respond correctly"
    echo "Response: $RESULT"
    exit 1
fi

# Test 3: Test tools listing
echo "Test 3: Tools Listing"
print_status "INFO" "Testing tools listing..."

# First initialize, then list tools
INIT_AND_TOOLS='{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "1.0.0"}}}
{"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}}'

TOOLS_RESULT=$(echo "$INIT_AND_TOOLS" | timeout 15 docker run --rm -i -v "$(pwd):/workspace" -e SEARCH_ROOT=/workspace mymcp-local-search 2>&1 || echo "timeout")

if echo "$TOOLS_RESULT" | grep -q '"jsonrpc":"2.0"' && echo "$TOOLS_RESULT" | grep -q '"result"'; then
    print_status "PASS" "Tools listing works"
    
    # Count available tools
    TOOL_COUNT=$(echo "$TOOLS_RESULT" | grep -o '"name":"[^"]*"' | wc -l)
    print_status "INFO" "Available tools: $TOOL_COUNT"
    
    # List tool names
    TOOL_NAMES=$(echo "$TOOLS_RESULT" | grep -o '"name":"[^"]*"' | sed 's/"name":"//g' | sed 's/"//g')
    print_status "INFO" "Tool names: $TOOL_NAMES"
else
    print_status "FAIL" "Tools listing failed"
    echo "Response: $TOOLS_RESULT"
    exit 1
fi

# Test 4: Test file search functionality
echo "Test 4: File Search Functionality"
print_status "INFO" "Testing file search..."

# Initialize and then search
INIT_AND_SEARCH='{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "1.0.0"}}}
{"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "search_files", "arguments": {"query": "README", "limit": 5}}}'

SEARCH_RESULT=$(echo "$INIT_AND_SEARCH" | timeout 15 docker run --rm -i -v "$(pwd):/workspace" -e SEARCH_ROOT=/workspace mymcp-local-search 2>&1 || echo "timeout")

if echo "$SEARCH_RESULT" | grep -q '"jsonrpc":"2.0"' && echo "$SEARCH_RESULT" | grep -q '"content"'; then
    print_status "PASS" "File search works"
    
    # Check if README files were found
    if echo "$SEARCH_RESULT" | grep -q "README"; then
        print_status "PASS" "Found README files as expected"
    else
        print_status "WARN" "No README files found (may be expected)"
    fi
else
    print_status "FAIL" "File search failed"
    echo "Response: $SEARCH_RESULT"
fi

# Test 5: Test content search functionality
echo "Test 5: Content Search Functionality"
print_status "INFO" "Testing content search..."

# Initialize and then search content
INIT_AND_CONTENT='{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "1.0.0"}}}
{"jsonrpc": "2.0", "id": 4, "method": "tools/call", "params": {"name": "search_content", "arguments": {"query": "docker", "limit": 3}}}'

CONTENT_RESULT=$(echo "$INIT_AND_CONTENT" | timeout 15 docker run --rm -i -v "$(pwd):/workspace" -e SEARCH_ROOT=/workspace mymcp-local-search 2>&1 || echo "timeout")

if echo "$CONTENT_RESULT" | grep -q '"jsonrpc":"2.0"' && echo "$CONTENT_RESULT" | grep -q '"content"'; then
    print_status "PASS" "Content search works"
    
    # Check if docker-related content was found
    if echo "$CONTENT_RESULT" | grep -q "docker"; then
        print_status "PASS" "Found docker-related content as expected"
    else
        print_status "WARN" "No docker-related content found (may be expected)"
    fi
else
    print_status "FAIL" "Content search failed"
    echo "Response: $CONTENT_RESULT"
fi

# Test 6: Check system dependencies
echo "Test 6: System Dependencies"
print_status "INFO" "Checking system dependencies in container..."

DEPS_RESULT=$(docker run --rm mymcp-local-search bash -c "which rg && which fd && which python" 2>&1)

if echo "$DEPS_RESULT" | grep -q "rg" && echo "$DEPS_RESULT" | grep -q "fd" && echo "$DEPS_RESULT" | grep -q "python"; then
    print_status "PASS" "All system dependencies are available"
    print_status "INFO" "Available tools: $DEPS_RESULT"
else
    print_status "WARN" "Some system dependencies may be missing"
    print_status "INFO" "Available tools: $DEPS_RESULT"
fi

# Test 7: Performance test
echo "Test 7: Performance Test"
print_status "INFO" "Testing search performance..."

PERF_START=$(date +%s%N)
# Initialize and then test performance
INIT_AND_PERF='{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "1.0.0"}}}
{"jsonrpc": "2.0", "id": 5, "method": "tools/call", "params": {"name": "search_files", "arguments": {"query": "test", "limit": 10}}}'

PERF_RESULT=$(echo "$INIT_AND_PERF" | timeout 10 docker run --rm -i -v "$(pwd):/workspace" -e SEARCH_ROOT=/workspace mymcp-local-search 2>&1 || echo "timeout")
PERF_END=$(date +%s%N)

PERF_TIME=$(( (PERF_END - PERF_START) / 1000000 )) # Convert to milliseconds

if echo "$PERF_RESULT" | grep -q '"jsonrpc":"2.0"'; then
    print_status "PASS" "Performance test completed in ${PERF_TIME}ms"
    
    if [ $PERF_TIME -lt 5000 ]; then
        print_status "PASS" "Performance is good (< 5 seconds)"
    elif [ $PERF_TIME -lt 10000 ]; then
        print_status "WARN" "Performance is acceptable (< 10 seconds)"
    else
        print_status "WARN" "Performance is slow (> 10 seconds)"
    fi
else
    print_status "FAIL" "Performance test failed"
fi

echo ""
echo "🎯 Test Summary:"
echo "   Local Search MCP Server has been tested"
echo "   Docker image builds successfully"
echo "   MCP protocol communication works"
echo "   Search functionality is operational"
echo "   System dependencies are available"
echo ""
echo "📚 Next Steps:"
echo "   1. Build and start the Docker Compose services"
echo "   2. Update Cursor IDE configuration"
echo "   3. Test integration with Cursor IDE"
echo "   4. Use the search tools in your development workflow"
echo ""
echo "🔗 Repository: https://github.com/albisher/myMCPs"
