#!/bin/bash

# myMCPs Auto-start Installation Script
# This script installs systemd service to auto-start myMCPs on boot

set -e

echo "🚀 Installing myMCPs Auto-start Service..."

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

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_status "FAIL" "This script should not be run as root. Please run as regular user."
    exit 1
fi

# Get current user and project directory
CURRENT_USER=$(whoami)
PROJECT_DIR=$(pwd)

print_status "INFO" "Installing auto-start for user: $CURRENT_USER"
print_status "INFO" "Project directory: $PROJECT_DIR"

# Check if systemd is available
if ! command -v systemctl &> /dev/null; then
    print_status "FAIL" "systemd is not available on this system"
    exit 1
fi

# Check if docker compose is available
if ! command -v docker &> /dev/null; then
    print_status "FAIL" "Docker is not installed or not in PATH"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    print_status "FAIL" "Docker Compose is not available"
    exit 1
fi

# Update the service file with correct paths
print_status "INFO" "Updating service file with correct paths..."

# Create the service file with correct user and directory
cat > mymcp.service << EOF
[Unit]
Description=myMCPs Docker Compose Services
Requires=docker.service
After=docker.service
StartLimitInterval=0

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$PROJECT_DIR
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0
User=$CURRENT_USER
Group=$CURRENT_USER

[Install]
WantedBy=multi-user.target
EOF

print_status "PASS" "Service file created with correct paths"

# Copy service file to systemd directory
print_status "INFO" "Installing systemd service..."
sudo cp mymcp.service /etc/systemd/system/

# Reload systemd daemon
print_status "INFO" "Reloading systemd daemon..."
sudo systemctl daemon-reload

# Enable the service
print_status "INFO" "Enabling myMCPs service..."
sudo systemctl enable mymcp.service

# Check service status
print_status "INFO" "Checking service status..."
if sudo systemctl is-enabled mymcp.service > /dev/null 2>&1; then
    print_status "PASS" "myMCPs service is enabled for auto-start"
else
    print_status "FAIL" "Failed to enable myMCPs service"
    exit 1
fi

# Test the service
print_status "INFO" "Testing service start..."
sudo systemctl start mymcp.service

# Wait a moment for services to start
sleep 5

# Check if services are running
if docker compose ps | grep -q "Up"; then
    print_status "PASS" "myMCPs services started successfully"
else
    print_status "WARN" "Services may not have started properly"
    print_status "INFO" "Check service status with: sudo systemctl status mymcp"
fi

# Show service status
print_status "INFO" "Service status:"
sudo systemctl status mymcp.service --no-pager -l

echo ""
echo "🎯 Installation Complete!"
echo ""
echo "📋 Service Information:"
echo "   Service Name: mymcp.service"
echo "   Status: $(sudo systemctl is-active mymcp.service)"
echo "   Enabled: $(sudo systemctl is-enabled mymcp.service)"
echo ""
echo "🔧 Management Commands:"
echo "   Start:    sudo systemctl start mymcp"
echo "   Stop:     sudo systemctl stop mymcp"
echo "   Restart:  sudo systemctl restart mymcp"
echo "   Status:   sudo systemctl status mymcp"
echo "   Logs:     sudo journalctl -u mymcp -f"
echo ""
echo "🚀 Auto-start is now configured!"
echo "   The myMCPs services will automatically start on system boot"
echo "   and stop when the system shuts down."
echo ""
echo "📚 Next Steps:"
echo "   1. Reboot your system to test auto-start"
echo "   2. Check service status after reboot: sudo systemctl status mymcp"
echo "   3. Verify MCP services are running: docker compose ps"
echo ""
echo "🔗 Repository: https://github.com/albisher/myMCPs"
