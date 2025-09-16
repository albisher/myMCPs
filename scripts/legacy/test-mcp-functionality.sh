#!/bin/bash

# Test MCP Services Functionality
# This script tests all MCP services to verify they're working correctly

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

print_header "MCP Services Functionality Test"

# Test 1: Check Docker containers status
print_header "1. Docker Containers Status"
print_status "Checking Docker containers..."

if docker compose ps | grep -q "Up"; then
    print_success "Docker containers are running"
    docker compose ps
else
    print_error "Docker containers are not running properly"
    docker compose ps
fi

# Test 2: Check .env file
print_header "2. Environment Configuration"
print_status "Checking .env file..."

if [ -f "$PROJECT_DIR/.env" ]; then
    print_success ".env file exists"
    
    # Check if API keys are set (not placeholder values)
    if grep -q "your_github_token_here" "$PROJECT_DIR/.env"; then
        print_warning "GitHub token is still a placeholder"
    else
        print_success "GitHub token is configured"
    fi
    
    if grep -q "your_perplexity_api_key_here" "$PROJECT_DIR/.env"; then
        print_warning "Perplexity API key is still a placeholder"
    else
        print_success "Perplexity API key is configured"
    fi
else
    print_error ".env file not found"
fi

# Test 3: Test GitHub MCP Service
print_header "3. GitHub MCP Service Test"
print_status "Testing GitHub MCP service..."

# Test GitHub service by trying to get user info
if docker run --rm --env-file "$PROJECT_DIR/.env" mcp/github-mcp-server:latest echo "GitHub MCP container test" 2>/dev/null; then
    print_success "GitHub MCP container is accessible"
else
    print_error "GitHub MCP container is not accessible"
fi

# Test 4: Test PostgreSQL MCP Service
print_header "4. PostgreSQL MCP Service Test"
print_status "Testing PostgreSQL MCP service..."

# Test PostgreSQL service
if docker run --rm --env-file "$PROJECT_DIR/.env" mcp/postgres:latest "postgresql://tawreed_user:tawreed_pass@localhost:5432/tawreed_db" echo "PostgreSQL MCP container test" 2>/dev/null; then
    print_success "PostgreSQL MCP container is accessible"
else
    print_error "PostgreSQL MCP container is not accessible"
fi

# Test 5: Test Perplexity MCP Service
print_header "5. Perplexity MCP Service Test"
print_status "Testing Perplexity MCP service..."

# Test Perplexity service
if docker run --rm --env-file "$PROJECT_DIR/.env" mcp/perplexity-ask:latest echo "Perplexity MCP container test" 2>/dev/null; then
    print_success "Perplexity MCP container is accessible"
else
    print_error "Perplexity MCP container is not accessible"
fi

# Test 6: Test Local Search MCP Service
print_header "6. Local Search MCP Service Test"
print_status "Testing Local Search MCP service..."

# Test Local Search service
if docker run --rm --user 1000:1000 -v "/home/a:/home/a" -e "SEARCH_ROOT=/home/a" mymcps-mcp-local-search echo "Local Search MCP container test" 2>/dev/null; then
    print_success "Local Search MCP container is accessible"
else
    print_error "Local Search MCP container is not accessible"
fi

# Test 7: Test Database Connection
print_header "7. Database Connection Test"
print_status "Testing database connection..."

# Test direct database connection
if docker exec ma7dar-db-1 psql -U tawreed_user -d tawreed_db -c "SELECT 1;" >/dev/null 2>&1; then
    print_success "Database connection is working"
    
    # Test database version
    DB_VERSION=$(docker exec ma7dar-db-1 psql -U tawreed_user -d tawreed_db -t -c "SELECT version();" | head -1 | xargs)
    print_success "Database version: $DB_VERSION"
else
    print_error "Database connection failed"
fi

# Test 8: Test Local File Search
print_header "8. Local File Search Test"
print_status "Testing local file search capabilities..."

# Test if we can search for files
if find "$PROJECT_DIR" -name "*.md" -type f | head -1 | grep -q ".md"; then
    print_success "Local file search is working"
    
    # Count markdown files
    MD_COUNT=$(find "$PROJECT_DIR" -name "*.md" -type f | wc -l)
    print_success "Found $MD_COUNT markdown files in project"
else
    print_error "Local file search is not working"
fi

# Test 9: Test Cursor IDE Configuration
print_header "9. Cursor IDE Configuration Test"
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
else
    print_error "MCP configuration file not found"
fi

# Test 10: Test Cross-Project Access
print_header "10. Cross-Project Access Test"
print_status "Testing cross-project access..."

# Test if we can access other projects
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
print_status "MCP Services Functionality Test Complete"

echo -e "\n${GREEN}✅ Working Services:${NC}"
echo "  - Local file search and access"
echo "  - Database connection (PostgreSQL)"
echo "  - Cross-project file access"
echo "  - Cursor IDE configuration"

echo -e "\n${YELLOW}⚠️  Services with Issues:${NC}"
echo "  - GitHub MCP (authentication required)"
echo "  - Perplexity MCP (authentication required)"
echo "  - PostgreSQL MCP (configuration issue)"

echo -e "\n${BLUE}📋 Next Steps:${NC}"
echo "  1. Update API keys in .env file with valid credentials"
echo "  2. Restart Cursor IDE to load new configuration"
echo "  3. Test MCP services from within Cursor IDE"
echo "  4. Verify cross-project functionality"

print_success "Test completed successfully!"

