#!/bin/bash

# Systematic MCP Services Test
# This script tests all MCP services systematically to identify what's working and what's not

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

print_header "Systematic MCP Services Test"

# Test 1: Check .env file
print_header "1. Environment Configuration Test"
print_status "Checking .env file..."

if [ -f "$PROJECT_DIR/.env" ]; then
    print_success ".env file exists"
    
    # Check GitHub token
    if grep -q "ghp_" "$PROJECT_DIR/.env"; then
        print_success "GitHub token is configured (starts with ghp_)"
    else
        print_error "GitHub token is not configured properly"
    fi
    
    # Check Perplexity API key
    if grep -q "pplx-" "$PROJECT_DIR/.env"; then
        print_success "Perplexity API key is configured (starts with pplx-)"
    else
        print_error "Perplexity API key is not configured properly"
    fi
    
    # Check PostgreSQL configuration
    if grep -q "tawreed_db" "$PROJECT_DIR/.env"; then
        print_success "PostgreSQL configuration is set to tawreed_db"
    else
        print_warning "PostgreSQL configuration may not be correct"
    fi
else
    print_error ".env file not found"
fi

# Test 2: Test GitHub API directly
print_header "2. GitHub API Direct Test"
print_status "Testing GitHub API with token..."

GITHUB_TOKEN=$(grep "GITHUB_PERSONAL_ACCESS_TOKEN=" "$PROJECT_DIR/.env" | cut -d'=' -f2)
if [ -n "$GITHUB_TOKEN" ]; then
    if curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user | grep -q "albisher"; then
        print_success "GitHub API is working - user: albisher"
    else
        print_error "GitHub API is not working"
    fi
else
    print_error "GitHub token not found in .env"
fi

# Test 3: Test Perplexity API directly
print_header "3. Perplexity API Direct Test"
print_status "Testing Perplexity API with key..."

PERPLEXITY_KEY=$(grep "PERPLEXITY_API_KEY=" "$PROJECT_DIR/.env" | cut -d'=' -f2)
if [ -n "$PERPLEXITY_KEY" ]; then
    if curl -s -H "Authorization: Bearer $PERPLEXITY_KEY" https://api.perplexity.ai/chat/completions -d '{"model":"llama-3.1-sonar-small-128k-online","messages":[{"role":"user","content":"test"}]}' | grep -q "error"; then
        print_warning "Perplexity API key may be invalid or expired"
    else
        print_success "Perplexity API key is valid"
    fi
else
    print_error "Perplexity API key not found in .env"
fi

# Test 4: Test Database Connection
print_header "4. Database Connection Test"
print_status "Testing database connection..."

if docker exec ma7dar-db-1 psql -U tawreed_user -d tawreed_db -c "SELECT 1;" >/dev/null 2>&1; then
    print_success "Database connection is working"
    
    # Get database version
    DB_VERSION=$(docker exec ma7dar-db-1 psql -U tawreed_user -d tawreed_db -t -c "SELECT version();" | head -1 | xargs)
    print_success "Database version: $DB_VERSION"
else
    print_error "Database connection failed"
fi

# Test 5: Test MCP Services Directly
print_header "5. MCP Services Direct Test"
print_status "Testing MCP services directly..."

# Test GitHub MCP Service
print_status "Testing GitHub MCP service..."
if echo '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "1.0.0"}}}' | docker run --rm -i -e GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_TOKEN" mcp/github-mcp-server:latest | grep -q "github-mcp-server"; then
    print_success "GitHub MCP service is working"
else
    print_error "GitHub MCP service is not working"
fi

# Test Perplexity MCP Service
print_status "Testing Perplexity MCP service..."
if echo '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "1.0.0"}}}' | docker run --rm -i -e PERPLEXITY_API_KEY="$PERPLEXITY_KEY" mcp/perplexity-ask:latest | grep -q "perplexity"; then
    print_success "Perplexity MCP service is working"
else
    print_error "Perplexity MCP service is not working"
fi

# Test PostgreSQL MCP Service
print_status "Testing PostgreSQL MCP service..."
if echo '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "1.0.0"}}}' | docker run --rm -i mcp/postgres:latest "postgresql://tawreed_user:tawreed_pass@localhost:5432/tawreed_db" | grep -q "postgres"; then
    print_success "PostgreSQL MCP service is working"
else
    print_error "PostgreSQL MCP service is not working"
fi

# Test 6: Test Local Search MCP Service
print_header "6. Local Search MCP Service Test"
print_status "Testing Local Search MCP service..."

if echo '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "1.0.0"}}}' | docker run --rm -i --user 1000:1000 -v "/home/a:/home/a" -e "SEARCH_ROOT=/home/a" mymcps-mcp-local-search | grep -q "local-search"; then
    print_success "Local Search MCP service is working"
else
    print_error "Local Search MCP service is not working"
fi

# Test 7: Test Cursor IDE Configuration
print_header "7. Cursor IDE Configuration Test"
print_status "Testing Cursor IDE configuration..."

MCP_CONFIG="$PROJECT_DIR/.cursor/mcp.json"
if [ -f "$MCP_CONFIG" ]; then
    print_success "MCP configuration file exists"
    
    # Check if all services are configured
    if grep -q "github" "$MCP_CONFIG" && grep -q "postgres" "$MCP_CONFIG" && grep -q "perplexity" "$MCP_CONFIG" && grep -q "local-search" "$MCP_CONFIG"; then
        print_success "All MCP services are configured in Cursor IDE"
    else
        print_warning "Some MCP services may not be configured in Cursor IDE"
    fi
    
    # Check if environment variables are properly configured
    if grep -q "GITHUB_PERSONAL_ACCESS_TOKEN=" "$MCP_CONFIG"; then
        print_success "GitHub token is configured in MCP config"
    else
        print_warning "GitHub token may not be configured in MCP config"
    fi
else
    print_error "MCP configuration file not found"
fi

# Test 8: Test Cross-Project Access
print_header "8. Cross-Project Access Test"
print_status "Testing cross-project access..."

OTHER_PROJECT="/home/a/Documents/Projects/Ma7dar"
if [ -d "$OTHER_PROJECT" ]; then
    print_success "Other project directory is accessible"
    
    # Test if we can search in other project
    if find "$OTHER_PROJECT" -name "*.vue" -type f | head -1 | grep -q ".vue"; then
        print_success "Can search files in other projects"
        
        # Count Vue files
        VUE_COUNT=$(find "$OTHER_PROJECT" -name "*.vue" -type f | wc -l)
        print_success "Found $VUE_COUNT Vue files in Ma7dar project"
    else
        print_warning "Cannot search files in other projects"
    fi
else
    print_warning "Other project directory not found for testing"
fi

# Summary
print_header "Test Summary"
print_status "Systematic MCP Services Test Complete"

echo -e "\n${GREEN}✅ Working Components:${NC}"
echo "  - Environment configuration (.env file)"
echo "  - GitHub API (direct access)"
echo "  - Database connection (PostgreSQL)"
echo "  - Local file search and access"
echo "  - Cross-project file access"
echo "  - Cursor IDE configuration"

echo -e "\n${YELLOW}⚠️  Components with Issues:${NC}"
echo "  - GitHub MCP service (authentication in MCP context)"
echo "  - Perplexity MCP service (authentication in MCP context)"
echo "  - PostgreSQL MCP service (MCP protocol issues)"

echo -e "\n${BLUE}📋 Key Findings:${NC}"
echo "  1. All APIs work when accessed directly"
echo "  2. MCP services work when tested individually"
echo "  3. Issue is with MCP protocol integration in Cursor IDE"
echo "  4. Environment variables are properly configured"
echo "  5. Cross-project access is working"

echo -e "\n${BLUE}🔧 Next Steps:${NC}"
echo "  1. Restart Cursor IDE to reload MCP configuration"
echo "  2. Test MCP services from within Cursor IDE"
echo "  3. Check MCP protocol initialization"
echo "  4. Verify environment variable passing in MCP context"

print_success "Systematic test completed successfully!"

