#!/bin/bash

# myMCPs Auto-start Management Script
# This script provides easy management of the myMCPs auto-start service

set -e

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

# Function to show help
show_help() {
    echo "myMCPs Auto-start Management Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  status     - Show service status"
    echo "  start      - Start the service"
    echo "  stop       - Stop the service"
    echo "  restart    - Restart the service"
    echo "  enable     - Enable auto-start"
    echo "  disable    - Disable auto-start"
    echo "  logs       - Show service logs"
    echo "  install    - Install auto-start service"
    echo "  uninstall  - Remove auto-start service"
    echo "  lingering  - Enable/disable user lingering"
    echo "  help       - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 status          # Check if service is running"
    echo "  $0 restart         # Restart the MCP services"
    echo "  $0 logs            # View service logs"
    echo "  $0 lingering on    # Enable boot-time startup"
    echo "  $0 lingering off   # Disable boot-time startup"
}

# Function to check if service is installed
is_service_installed() {
    [ -f "$HOME/.config/systemd/user/mymcp.service" ]
}

# Function to show service status
show_status() {
    print_status "INFO" "myMCPs Auto-start Service Status"
    echo ""
    
    if is_service_installed; then
        print_status "PASS" "Service is installed"
        
        # Check if enabled
        if systemctl --user is-enabled mymcp.service > /dev/null 2>&1; then
            print_status "PASS" "Service is enabled for auto-start"
        else
            print_status "WARN" "Service is installed but not enabled"
        fi
        
        # Check if active
        if systemctl --user is-active mymcp.service > /dev/null 2>&1; then
            print_status "PASS" "Service is currently active"
        else
            print_status "WARN" "Service is not currently active"
        fi
        
        # Check lingering status
        local linger_status=$(loginctl show-user "$(whoami)" -p Linger 2>/dev/null | cut -d= -f2 || echo "no")
        if [ "$linger_status" = "yes" ]; then
            print_status "PASS" "User lingering is enabled (starts on boot)"
        else
            print_status "INFO" "User lingering is disabled (starts on login)"
        fi
        
        echo ""
        print_status "INFO" "Detailed service status:"
        systemctl --user status mymcp.service --no-pager -l
        
        echo ""
        print_status "INFO" "Docker services status:"
        docker compose ps
        
    else
        print_status "FAIL" "Service is not installed"
        print_status "INFO" "Run '$0 install' to install the auto-start service"
    fi
}

# Function to start service
start_service() {
    if ! is_service_installed; then
        print_status "FAIL" "Service is not installed. Run '$0 install' first."
        exit 1
    fi
    
    print_status "INFO" "Starting myMCPs service..."
    systemctl --user start mymcp.service
    
    sleep 3
    
    if systemctl --user is-active mymcp.service > /dev/null 2>&1; then
        print_status "PASS" "Service started successfully"
    else
        print_status "FAIL" "Failed to start service"
        exit 1
    fi
}

# Function to stop service
stop_service() {
    if ! is_service_installed; then
        print_status "FAIL" "Service is not installed. Run '$0 install' first."
        exit 1
    fi
    
    print_status "INFO" "Stopping myMCPs service..."
    systemctl --user stop mymcp.service
    
    if ! systemctl --user is-active mymcp.service > /dev/null 2>&1; then
        print_status "PASS" "Service stopped successfully"
    else
        print_status "FAIL" "Failed to stop service"
        exit 1
    fi
}

# Function to restart service
restart_service() {
    if ! is_service_installed; then
        print_status "FAIL" "Service is not installed. Run '$0 install' first."
        exit 1
    fi
    
    print_status "INFO" "Restarting myMCPs service..."
    systemctl --user restart mymcp.service
    
    sleep 3
    
    if systemctl --user is-active mymcp.service > /dev/null 2>&1; then
        print_status "PASS" "Service restarted successfully"
    else
        print_status "FAIL" "Failed to restart service"
        exit 1
    fi
}

# Function to enable service
enable_service() {
    if ! is_service_installed; then
        print_status "FAIL" "Service is not installed. Run '$0 install' first."
        exit 1
    fi
    
    print_status "INFO" "Enabling myMCPs auto-start..."
    systemctl --user enable mymcp.service
    
    if systemctl --user is-enabled mymcp.service > /dev/null 2>&1; then
        print_status "PASS" "Auto-start enabled successfully"
    else
        print_status "FAIL" "Failed to enable auto-start"
        exit 1
    fi
}

# Function to disable service
disable_service() {
    if ! is_service_installed; then
        print_status "FAIL" "Service is not installed. Run '$0 install' first."
        exit 1
    fi
    
    print_status "INFO" "Disabling myMCPs auto-start..."
    systemctl --user disable mymcp.service
    
    if ! systemctl --user is-enabled mymcp.service > /dev/null 2>&1; then
        print_status "PASS" "Auto-start disabled successfully"
    else
        print_status "FAIL" "Failed to disable auto-start"
        exit 1
    fi
}

# Function to show logs
show_logs() {
    if ! is_service_installed; then
        print_status "FAIL" "Service is not installed. Run '$0 install' first."
        exit 1
    fi
    
    print_status "INFO" "Showing myMCPs service logs (press Ctrl+C to exit):"
    journalctl --user -u mymcp -f
}

# Function to install service
install_service() {
    if is_service_installed; then
        print_status "WARN" "Service is already installed"
        print_status "INFO" "Use '$0 restart' to restart the service"
        return 0
    fi
    
    print_status "INFO" "Installing myMCPs auto-start service..."
    
    # Check if install script exists
    if [ -f "scripts/install-user-autostart.sh" ]; then
        ./scripts/install-user-autostart.sh
    else
        print_status "FAIL" "Install script not found: scripts/install-user-autostart.sh"
        exit 1
    fi
}

# Function to uninstall service
uninstall_service() {
    if ! is_service_installed; then
        print_status "WARN" "Service is not installed"
        return 0
    fi
    
    print_status "INFO" "Uninstalling myMCPs auto-start service..."
    
    # Stop and disable service
    systemctl --user stop mymcp.service 2>/dev/null || true
    systemctl --user disable mymcp.service 2>/dev/null || true
    
    # Remove service file
    rm -f "$HOME/.config/systemd/user/mymcp.service"
    
    # Reload systemd
    systemctl --user daemon-reload
    
    print_status "PASS" "Service uninstalled successfully"
}

# Function to manage lingering
manage_lingering() {
    local action=$1
    local current_user=$(whoami)
    
    case "$action" in
        "on"|"enable")
            print_status "INFO" "Enabling user lingering for $current_user..."
            sudo loginctl enable-linger "$current_user"
            print_status "PASS" "User lingering enabled - services will start on boot"
            ;;
        "off"|"disable")
            print_status "INFO" "Disabling user lingering for $current_user..."
            sudo loginctl disable-linger "$current_user"
            print_status "PASS" "User lingering disabled - services will start on login"
            ;;
        "status")
            local linger_status=$(loginctl show-user "$current_user" -p Linger 2>/dev/null | cut -d= -f2 || echo "no")
            if [ "$linger_status" = "yes" ]; then
                print_status "PASS" "User lingering is enabled (starts on boot)"
            else
                print_status "INFO" "User lingering is disabled (starts on login)"
            fi
            ;;
        *)
            print_status "FAIL" "Invalid lingering action. Use: on, off, or status"
            echo "Examples:"
            echo "  $0 lingering on     # Enable boot-time startup"
            echo "  $0 lingering off    # Disable boot-time startup"
            echo "  $0 lingering status # Check current status"
            exit 1
            ;;
    esac
}

# Main script logic
case "${1:-status}" in
    "status")
        show_status
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
    "enable")
        enable_service
        ;;
    "disable")
        disable_service
        ;;
    "logs")
        show_logs
        ;;
    "install")
        install_service
        ;;
    "uninstall")
        uninstall_service
        ;;
    "lingering")
        manage_lingering "$2"
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        print_status "FAIL" "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
