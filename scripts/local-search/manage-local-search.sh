#!/bin/bash

# Local Search MCP Management Script
# Production-ready script for managing the local search MCP server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_SEARCH_DIR="$PROJECT_ROOT/local-search-mcp"
DOCKER_IMAGE="mymcps-mcp-local-search"
CONTAINER_NAME="mymcp-local-search"

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

# Function to check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        print_status "ERROR" "Docker is not running. Please start Docker and try again."
        exit 1
    fi
}

# Function to build the Docker image
build_image() {
    print_status "INFO" "Building local search MCP Docker image..."
    
    if [ ! -d "$LOCAL_SEARCH_DIR" ]; then
        print_status "ERROR" "Local search MCP directory not found: $LOCAL_SEARCH_DIR"
        exit 1
    fi
    
    cd "$LOCAL_SEARCH_DIR"
    
    if docker build -t "$DOCKER_IMAGE" . >/dev/null 2>&1; then
        print_status "SUCCESS" "Docker image built successfully"
    else
        print_status "ERROR" "Failed to build Docker image"
        exit 1
    fi
}

# Function to start the local search MCP service
start_service() {
    print_status "INFO" "Starting local search MCP service..."
    
    # Check if container is already running
    if docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        print_status "WARNING" "Container $CONTAINER_NAME is already running"
        return 0
    fi
    
    # Start the service using Docker Compose
    cd "$PROJECT_ROOT"
    if docker compose up -d mcp-local-search; then
        print_status "SUCCESS" "Local search MCP service started"
        
        # Wait a moment for the service to initialize
        sleep 2
        
        # Check if the service is healthy
        if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "${CONTAINER_NAME}.*Up"; then
            print_status "SUCCESS" "Service is running and healthy"
        else
            print_status "WARNING" "Service started but may not be healthy yet"
        fi
    else
        print_status "ERROR" "Failed to start local search MCP service"
        exit 1
    fi
}

# Function to stop the local search MCP service
stop_service() {
    print_status "INFO" "Stopping local search MCP service..."
    
    cd "$PROJECT_ROOT"
    if docker compose stop mcp-local-search; then
        print_status "SUCCESS" "Local search MCP service stopped"
    else
        print_status "ERROR" "Failed to stop local search MCP service"
        exit 1
    fi
}

# Function to restart the local search MCP service
restart_service() {
    print_status "INFO" "Restarting local search MCP service..."
    stop_service
    sleep 1
    start_service
}

# Function to show service status
show_status() {
    print_status "INFO" "Local Search MCP Service Status:"
    echo
    
    # Check if container exists
    if docker ps -a --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        echo "Container Status:"
        docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep "$CONTAINER_NAME"
        echo
        
        # Check if container is running
        if docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
            print_status "SUCCESS" "Service is running"
            
            # Show resource usage
            echo "Resource Usage:"
            docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" "$CONTAINER_NAME"
            echo
            
            # Show logs (last 10 lines)
            echo "Recent Logs:"
            docker logs --tail 10 "$CONTAINER_NAME" 2>/dev/null || echo "No logs available"
        else
            print_status "WARNING" "Service is not running"
        fi
    else
        print_status "WARNING" "Container does not exist"
    fi
}

# Function to show service logs
show_logs() {
    print_status "INFO" "Showing local search MCP service logs..."
    
    if docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        docker logs -f "$CONTAINER_NAME"
    else
        print_status "ERROR" "Container $CONTAINER_NAME is not running"
        exit 1
    fi
}

# Function to clean up resources
cleanup() {
    print_status "INFO" "Cleaning up local search MCP resources..."
    
    # Stop and remove container
    cd "$PROJECT_ROOT"
    docker compose down mcp-local-search 2>/dev/null || true
    
    # Remove Docker image
    if docker images --format "table {{.Repository}}" | grep -q "^${DOCKER_IMAGE}$"; then
        docker rmi "$DOCKER_IMAGE" 2>/dev/null || true
        print_status "SUCCESS" "Docker image removed"
    fi
    
    # Remove volumes
    docker volume rm mymcps_local-search-data 2>/dev/null || true
    
    print_status "SUCCESS" "Cleanup completed"
}

# Function to update the service
update_service() {
    print_status "INFO" "Updating local search MCP service..."
    
    # Pull latest changes (if using git)
    if [ -d "$PROJECT_ROOT/.git" ]; then
        cd "$PROJECT_ROOT"
        git pull origin main 2>/dev/null || print_status "WARNING" "Could not pull latest changes"
    fi
    
    # Rebuild and restart
    build_image
    restart_service
    
    print_status "SUCCESS" "Service updated successfully"
}

# Function to show help
show_help() {
    echo "Local Search MCP Management Script"
    echo
    echo "Usage: $0 [COMMAND]"
    echo
    echo "Commands:"
    echo "  build       Build the Docker image"
    echo "  start       Start the local search MCP service"
    echo "  stop        Stop the local search MCP service"
    echo "  restart     Restart the local search MCP service"
    echo "  status      Show service status and information"
    echo "  logs        Show service logs (follow mode)"
    echo "  update      Update and restart the service"
    echo "  cleanup     Clean up all resources"
    echo "  help        Show this help message"
    echo
    echo "Examples:"
    echo "  $0 build    # Build the Docker image"
    echo "  $0 start    # Start the service"
    echo "  $0 status   # Check service status"
    echo "  $0 logs     # View service logs"
}

# Main script logic
main() {
    # Check if Docker is available
    check_docker
    
    # Parse command
    case "${1:-help}" in
        "build")
            build_image
            ;;
        "start")
            start_service
            ;;
        "stop")
            stop_service
            ;;
        "restart")
            restart_service
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs
            ;;
        "update")
            update_service
            ;;
        "cleanup")
            cleanup
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
