#!/bin/bash

# myMCPs User Auto-start Installation Script
# This script installs user systemd service to auto-start myMCPs on login

set -e

echo "🚀 Installing myMCPs User Auto-start Service..."

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

# Get current user and project directory
CURRENT_USER=$(whoami)
PROJECT_DIR=$(pwd)
USER_SYSTEMD_DIR="$HOME/.config/systemd/user"

print_status "INFO" "Installing user auto-start for user: $CURRENT_USER"
print_status "INFO" "Project directory: $PROJECT_DIR"
print_status "INFO" "User systemd directory: $USER_SYSTEMD_DIR"

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

# Create user systemd directory if it doesn't exist
print_status "INFO" "Creating user systemd directory..."
mkdir -p "$USER_SYSTEMD_DIR"

# Create the user service file
print_status "INFO" "Creating user service file..."

cat > "$USER_SYSTEMD_DIR/mymcp.service" << EOF
[Unit]
Description=myMCPs Docker Compose Services
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$PROJECT_DIR
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0
Environment=HOME=$HOME
Environment=USER=$CURRENT_USER

[Install]
WantedBy=default.target
EOF

print_status "PASS" "User service file created"

# Reload user systemd daemon
print_status "INFO" "Reloading user systemd daemon..."
systemctl --user daemon-reload

# Enable the service
print_status "INFO" "Enabling myMCPs user service..."
systemctl --user enable mymcp.service

# Enable lingering for the user (allows user services to start without login)
print_status "INFO" "Enabling user lingering..."
sudo loginctl enable-linger "$CURRENT_USER" 2>/dev/null || {
    print_status "WARN" "Could not enable lingering (requires sudo). Service will start on user login instead."
}

# Check service status
print_status "INFO" "Checking service status..."
if systemctl --user is-enabled mymcp.service > /dev/null 2>&1; then
    print_status "PASS" "myMCPs user service is enabled for auto-start"
else
    print_status "FAIL" "Failed to enable myMCPs user service"
    exit 1
fi

# Test the service
print_status "INFO" "Testing service start..."
systemctl --user start mymcp.service

# Wait a moment for services to start
sleep 5

# Check if services are running
if docker compose ps | grep -q "Up"; then
    print_status "PASS" "myMCPs services started successfully"
else
    print_status "WARN" "Services may not have started properly"
    print_status "INFO" "Check service status with: systemctl --user status mymcp"
fi

# Show service status
print_status "INFO" "Service status:"
systemctl --user status mymcp.service --no-pager -l

echo ""
echo "🎯 Installation Complete!"
echo ""
echo "📋 Service Information:"
echo "   Service Name: mymcp.service (user service)"
echo "   Status: $(systemctl --user is-active mymcp.service)"
echo "   Enabled: $(systemctl --user is-enabled mymcp.service)"
echo "   Lingering: $(loginctl show-user "$CURRENT_USER" -p Linger 2>/dev/null | cut -d= -f2 || echo 'Not enabled')"
echo ""
echo "🔧 Management Commands:"
echo "   Start:    systemctl --user start mymcp"
echo "   Stop:     systemctl --user stop mymcp"
echo "   Restart:  systemctl --user restart mymcp"
echo "   Status:   systemctl --user status mymcp"
echo "   Logs:     journalctl --user -u mymcp -f"
echo ""
echo "🚀 Auto-start is now configured!"
if loginctl show-user "$CURRENT_USER" -p Linger 2>/dev/null | grep -q "yes"; then
    echo "   The myMCPs services will automatically start on system boot"
else
    echo "   The myMCPs services will automatically start when you log in"
fi
echo "   and stop when you log out or the system shuts down."
echo ""
echo "📚 Next Steps:"
echo "   1. Reboot your system to test auto-start"
echo "   2. Check service status after reboot: systemctl --user status mymcp"
echo "   3. Verify MCP services are running: docker compose ps"
echo ""
echo "💡 Note: If you want services to start on boot (not just login),"
echo "   run: sudo loginctl enable-linger $CURRENT_USER"
echo ""
echo "🔗 Repository: https://github.com/albisher/myMCPs"
