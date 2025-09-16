#!/bin/bash

# myMCPs Test Setup Script
# This script tests the Docker MCP servers setup

set -e

echo "🧪 Testing myMCPs Docker MCP Servers Setup..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✅ $message${NC}"
    elif [ "$status" = "FAIL" ]; then
        echo -e "${RED}❌ $message${NC}"
    else
        echo -e "${YELLOW}⚠️  $message${NC}"
    fi
}

# Test 1: Check if Docker is running
echo "Test 1: Docker Status"
if docker info > /dev/null 2>&1; then
    print_status "PASS" "Docker is running"
else
    print_status "FAIL" "Docker is not running"
    exit 1
fi

# Test 2: Check if Docker Compose is available
echo "Test 2: Docker Compose"
if command -v docker-compose &> /dev/null; then
    print_status "PASS" "Docker Compose is available"
else
    print_status "FAIL" "Docker Compose is not installed"
    exit 1
fi

# Test 3: Check if .env file exists
echo "Test 3: Environment Configuration"
if [ -f .env ]; then
    print_status "PASS" ".env file exists"
    
    # Check if required variables are set
    if grep -q "GITHUB_PERSONAL_ACCESS_TOKEN=" .env && ! grep -q "your_github_token_here" .env; then
        print_status "PASS" "GitHub token is configured"
    else
        print_status "WARN" "GitHub token needs to be configured"
    fi
    
    if grep -q "PERPLEXITY_API_KEY=" .env && ! grep -q "your_perplexity_api_key_here" .env; then
        print_status "PASS" "Perplexity API key is configured"
    else
        print_status "WARN" "Perplexity API key needs to be configured (optional)"
    fi
else
    print_status "FAIL" ".env file does not exist. Run ./scripts/setup.sh first"
    exit 1
fi

# Test 4: Check if MCP server images are available
echo "Test 4: MCP Server Images"
images=("mcp/github-mcp-server:latest" "mcp/postgres:latest" "mcp/perplexity-ask:latest")

for image in "${images[@]}"; do
    if docker image inspect "$image" > /dev/null 2>&1; then
        print_status "PASS" "Image $image is available"
    else
        print_status "WARN" "Image $image not found locally. Will be pulled on startup"
    fi
done

# Test 5: Check if services are running
echo "Test 5: Service Status"
if docker-compose ps | grep -q "Up"; then
    print_status "PASS" "MCP services are running"
    
    # Test individual service endpoints
    services=("8081:GitHub MCP Server" "8082:PostgreSQL MCP Server" "8083:Perplexity MCP Server")
    
    for service in "${services[@]}"; do
        port=$(echo $service | cut -d: -f1)
        name=$(echo $service | cut -d: -f2)
        
        if curl -s -f "http://localhost:$port" > /dev/null 2>&1; then
            print_status "PASS" "$name is accessible on port $port"
        else
            print_status "WARN" "$name is not accessible on port $port"
        fi
    done
else
    print_status "WARN" "MCP services are not running. Start them with: docker-compose up -d"
fi

# Test 6: Check Cursor IDE configuration
echo "Test 6: Cursor IDE Configuration"
if [ -f .cursor/mcp.json ]; then
    print_status "PASS" "Cursor MCP configuration exists"
    
    # Validate JSON syntax
    if command -v jq &> /dev/null; then
        if jq . .cursor/mcp.json > /dev/null 2>&1; then
            print_status "PASS" "Cursor MCP configuration is valid JSON"
        else
            print_status "FAIL" "Cursor MCP configuration has invalid JSON syntax"
        fi
    else
        print_status "WARN" "jq not available - cannot validate JSON syntax"
    fi
else
    print_status "FAIL" "Cursor MCP configuration not found"
fi

# Test 7: Check script permissions
echo "Test 7: Script Permissions"
scripts=("scripts/setup.sh" "scripts/health-check.sh" "scripts/test-setup.sh")

for script in "${scripts[@]}"; do
    if [ -x "$script" ]; then
        print_status "PASS" "$script is executable"
    else
        print_status "FAIL" "$script is not executable"
    fi
done

echo ""
echo "🎯 Test Summary:"
echo "   Run './scripts/health-check.sh' for detailed service health information"
echo "   Run 'docker-compose logs' to view service logs"
echo "   Run 'docker-compose ps' to check service status"
echo ""
echo "📚 Next Steps:"
echo "   1. Configure your API keys in .env file"
echo "   2. Copy .cursor/mcp.json to your Cursor IDE configuration"
echo "   3. Restart Cursor IDE"
echo "   4. Test MCP integration in Cursor IDE"
echo ""
echo "🔗 Repository: https://github.com/albisher/myMCPs"
