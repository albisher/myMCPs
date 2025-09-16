#!/bin/bash

# Local Search MCP Integration Script
# Production-ready script for integrating local search MCP with the existing system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CURSOR_CONFIG="$PROJECT_ROOT/.cursor/mcp.json"
DOCKER_COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    if [ "$status" = "SUCCESS" ]; then
        echo -e "${GREEN}✅ $message${NC}"
    elif [ "$status" = "ERROR" ]; then
        echo -e "${RED}❌ $message${NC}"
    elif [ "$status" = "INFO" ]; then
        echo -e "${BLUE}ℹ️  $message${NC}"
    elif [ "$status" = "WARNING" ]; then
        echo -e "${YELLOW}⚠️  $message${NC}"
    else
        echo -e "$message"
    fi
}

# Function to check prerequisites
check_prerequisites() {
    print_status "INFO" "Checking prerequisites..."
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        print_status "ERROR" "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    
    # Check if Docker Compose is available
    if ! command -v docker >/dev/null 2>&1; then
        print_status "ERROR" "Docker is not installed or not in PATH."
        exit 1
    fi
    
    # Check if required files exist
    if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
        print_status "ERROR" "Docker Compose file not found: $DOCKER_COMPOSE_FILE"
        exit 1
    fi
    
    if [ ! -f "$CURSOR_CONFIG" ]; then
        print_status "ERROR" "Cursor MCP configuration not found: $CURSOR_CONFIG"
        exit 1
    fi
    
    print_status "SUCCESS" "All prerequisites met"
}

# Function to verify Docker Compose integration
verify_docker_compose() {
    print_status "INFO" "Verifying Docker Compose integration..."
    
    # Check if volume is defined (for local search data)
    if grep -q "local-search-data:" "$DOCKER_COMPOSE_FILE"; then
        print_status "SUCCESS" "Local search volume found in Docker Compose"
    else
        print_status "WARNING" "Local search volume not found in Docker Compose"
    fi
    
    # Validate Docker Compose syntax
    if docker compose config >/dev/null 2>&1; then
        print_status "SUCCESS" "Docker Compose configuration is valid"
    else
        print_status "ERROR" "Docker Compose configuration is invalid"
        exit 1
    fi
    
    # Note: Local search MCP runs on-demand via Cursor IDE, not as a persistent service
    print_status "INFO" "Local search MCP is designed to run on-demand by Cursor IDE"
}

# Function to verify Cursor IDE integration
verify_cursor_integration() {
    print_status "INFO" "Verifying Cursor IDE integration..."
    
    # Check if local-search is configured in Cursor
    if grep -q '"local-search":' "$CURSOR_CONFIG"; then
        print_status "SUCCESS" "Local search MCP found in Cursor configuration"
    else
        print_status "ERROR" "Local search MCP not found in Cursor configuration"
        exit 1
    fi
    
    # Check if the Docker image name is correct
    if grep -q "mymcps-mcp-local-search" "$CURSOR_CONFIG"; then
        print_status "SUCCESS" "Correct Docker image name in Cursor configuration"
    else
        print_status "WARNING" "Docker image name may be incorrect in Cursor configuration"
    fi
    
    # Validate JSON syntax
    if jq empty "$CURSOR_CONFIG" 2>/dev/null; then
        print_status "SUCCESS" "Cursor MCP configuration JSON is valid"
    else
        print_status "ERROR" "Cursor MCP configuration JSON is invalid"
        exit 1
    fi
}

# Function to build and start services
build_and_start() {
    print_status "INFO" "Building and starting all MCP services..."
    
    cd "$PROJECT_ROOT"
    
    # Build all services
    if docker compose build; then
        print_status "SUCCESS" "All services built successfully"
    else
        print_status "ERROR" "Failed to build services"
        exit 1
    fi
    
    # Start all services
    if docker compose up -d; then
        print_status "SUCCESS" "All services started successfully"
    else
        print_status "ERROR" "Failed to start services"
        exit 1
    fi
    
    # Wait for services to initialize
    print_status "INFO" "Waiting for services to initialize..."
    sleep 5
    
    # Check service status
    show_service_status
}

# Function to show service status
show_service_status() {
    print_status "INFO" "MCP Services Status:"
    echo
    
    # Get service status
    docker compose ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}"
    echo
    
    # Check individual service health
    local services=("mcp-github" "mcp-postgres" "mcp-perplexity" "mcp-local-search")
    
    for service in "${services[@]}"; do
        if docker compose ps --format "{{.Status}}" "$service" | grep -q "Up"; then
            print_status "SUCCESS" "$service is running"
        else
            print_status "WARNING" "$service is not running properly"
        fi
    done
}

# Function to test local search functionality
test_local_search() {
    print_status "INFO" "Testing local search functionality..."
    
    # Test Docker image build and basic functionality
    if docker images --format "{{.Repository}}" | grep -q "mymcps-mcp-local-search"; then
        print_status "SUCCESS" "Local search Docker image is available"
    else
        print_status "WARNING" "Local search Docker image not found, building..."
        cd "$PROJECT_ROOT/local-search-mcp"
        if docker build -t mymcps-mcp-local-search . >/dev/null 2>&1; then
            print_status "SUCCESS" "Local search Docker image built successfully"
        else
            print_status "ERROR" "Failed to build local search Docker image"
            return 1
        fi
    fi
    
    # Test basic container functionality
    if docker run --rm mymcps-mcp-local-search python -c "print('Python is working')" >/dev/null 2>&1; then
        print_status "SUCCESS" "Local search container Python environment is working"
    else
        print_status "WARNING" "Local search container Python environment may have issues"
    fi
    
    # Test if required tools are available
    local tools=("rg" "python")
    for tool in "${tools[@]}"; do
        if docker run --rm mymcps-mcp-local-search which "$tool" >/dev/null 2>&1; then
            print_status "SUCCESS" "Tool $tool is available in container"
        else
            print_status "WARNING" "Tool $tool is not available in container"
        fi
    done
    
    # Check for fd (fdfind)
    if docker run --rm mymcps-mcp-local-search which fdfind >/dev/null 2>&1; then
        print_status "SUCCESS" "Tool fdfind (fd) is available in container"
    else
        print_status "WARNING" "Tool fdfind (fd) is not available in container"
    fi
}

# Function to create systemd service for auto-start
create_systemd_service() {
    print_status "INFO" "Creating systemd service for auto-start..."
    
    local service_file="$PROJECT_ROOT/mymcp-local-search.service"
    
    cat > "$service_file" << EOF
[Unit]
Description=MyMCPs Local Search MCP Server
After=docker.service
Requires=docker.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$PROJECT_ROOT
ExecStart=/usr/bin/docker compose up -d mcp-local-search
ExecStop=/usr/bin/docker compose stop mcp-local-search
ExecReload=/usr/bin/docker compose restart mcp-local-search
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
EOF
    
    print_status "SUCCESS" "Systemd service file created: $service_file"
    print_status "INFO" "To install the service, run:"
    echo "  cp $service_file ~/.config/systemd/user/"
    echo "  systemctl --user daemon-reload"
    echo "  systemctl --user enable mymcp-local-search.service"
    echo "  systemctl --user start mymcp-local-search.service"
}

# Function to update documentation
update_documentation() {
    print_status "INFO" "Updating documentation..."
    
    # Update README.md if it exists
    if [ -f "$PROJECT_ROOT/README.md" ]; then
        # Check if local search is already documented
        if ! grep -q "Local Search" "$PROJECT_ROOT/README.md"; then
            print_status "INFO" "Adding local search documentation to README.md"
            
            # Add local search section to README
            cat >> "$PROJECT_ROOT/README.md" << 'EOF'

## Local Search MCP

The project now includes a high-performance local search MCP server that provides fast, token-free search capabilities for your local codebase.

### Features
- **File Search**: Fast file name and path search using `fd` (fd-find)
- **Content Search**: Full-text search using `ripgrep` (rg) for maximum speed
- **Regex Search**: Regular expression search with full pattern support
- **Advanced File Finding**: Search by size, date, type, and other criteria

### Usage
The local search MCP is automatically available in Cursor IDE when the services are running. Use the following tools:
- `search_files`: Search for files by name
- `search_content`: Search for text content within files
- `search_regex`: Search using regular expressions
- `find_files`: Find files by various criteria
- `get_file_info`: Get detailed information about a specific file

### Management
Use the management script to control the local search service:
```bash
./scripts/manage-local-search.sh [build|start|stop|restart|status|logs|update|cleanup]
```
EOF
        else
            print_status "SUCCESS" "Local search is already documented in README.md"
        fi
    fi
}

# Function to perform full integration
full_integration() {
    print_status "INFO" "Performing full local search MCP integration..."
    
    check_prerequisites
    verify_docker_compose
    verify_cursor_integration
    build_and_start
    test_local_search
    create_systemd_service
    update_documentation
    
    print_status "SUCCESS" "Local search MCP integration completed successfully!"
    echo
    print_status "INFO" "Next steps:"
    echo "  1. Restart Cursor IDE to load the new MCP configuration"
    echo "  2. Test the local search functionality in Cursor"
    echo "  3. Optionally install the systemd service for auto-start"
    echo
    print_status "INFO" "Use './scripts/manage-local-search.sh status' to check service status"
}

# Function to show help
show_help() {
    echo "Local Search MCP Integration Script"
    echo
    echo "Usage: $0 [COMMAND]"
    echo
    echo "Commands:"
    echo "  integrate   Perform full integration (default)"
    echo "  verify      Verify current integration"
    echo "  build       Build and start all services"
    echo "  test        Test local search functionality"
    echo "  status      Show service status"
    echo "  systemd     Create systemd service file"
    echo "  docs        Update documentation"
    echo "  help        Show this help message"
    echo
    echo "Examples:"
    echo "  $0                    # Perform full integration"
    echo "  $0 verify            # Verify current setup"
    echo "  $0 build             # Build and start services"
    echo "  $0 test              # Test functionality"
}

# Main script logic
main() {
    case "${1:-integrate}" in
        "integrate")
            full_integration
            ;;
        "verify")
            check_prerequisites
            verify_docker_compose
            verify_cursor_integration
            show_service_status
            ;;
        "build")
            check_prerequisites
            build_and_start
            ;;
        "test")
            test_local_search
            ;;
        "status")
            show_service_status
            ;;
        "systemd")
            create_systemd_service
            ;;
        "docs")
            update_documentation
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            print_status "ERROR" "Unknown command: $1"
            echo
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
