#!/bin/bash

# myMCPs System Auto-start Installation Script
# This script installs systemd service to auto-start myMCPs on boot with auto-restart

set -e

echo "🚀 Installing myMCPs System Auto-start Service..."

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

print_status "INFO" "Installing system auto-start for user: $CURRENT_USER"
print_status "INFO" "Project directory: $PROJECT_DIR"

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_status "FAIL" "This script should not be run as root. Please run as regular user."
    exit 1
fi

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

# Check if user is in docker group
if ! groups $CURRENT_USER | grep -q docker; then
    print_status "WARN" "User $CURRENT_USER is not in docker group"
    print_status "INFO" "Adding user to docker group..."
    sudo usermod -aG docker $CURRENT_USER
    print_status "PASS" "User added to docker group. Please log out and log back in for changes to take effect."
fi

# Create the system service file with auto-restart capabilities
print_status "INFO" "Creating system service file with auto-restart..."

sudo tee /etc/systemd/system/mymcp.service > /dev/null << EOF
[Unit]
Description=myMCPs Docker Compose Services
Requires=docker.service
After=docker.service
StartLimitInterval=0
StartLimitBurst=0

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$PROJECT_DIR
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
ExecReload=/usr/bin/docker compose restart
TimeoutStartSec=300
TimeoutStopSec=60
User=$CURRENT_USER
Group=$CURRENT_USER
Environment=HOME=$HOME
Environment=USER=$CURRENT_USER
Restart=always
RestartSec=10

# Auto-restart on failure
RestartPreventExitStatus=0
KillMode=mixed
KillSignal=SIGTERM

# Resource limits
MemoryLimit=2G
CPUQuota=100%

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=$PROJECT_DIR

[Install]
WantedBy=multi-user.target
EOF

print_status "PASS" "System service file created with auto-restart capabilities"

# Create a watchdog service for additional monitoring
print_status "INFO" "Creating watchdog service..."

sudo tee /etc/systemd/system/mymcp-watchdog.service > /dev/null << EOF
[Unit]
Description=myMCPs Docker Services Watchdog
Requires=mymcp.service
After=mymcp.service
StartLimitInterval=0

[Service]
Type=simple
WorkingDirectory=$PROJECT_DIR
ExecStart=/bin/bash -c 'while true; do if ! docker compose ps | grep -q "Up"; then echo "Services down, restarting..."; docker compose up -d; fi; sleep 30; done'
User=$CURRENT_USER
Group=$CURRENT_USER
Environment=HOME=$HOME
Environment=USER=$CURRENT_USER
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

print_status "PASS" "Watchdog service created"

# Reload systemd daemon
print_status "INFO" "Reloading systemd daemon..."
sudo systemctl daemon-reload

# Enable the services
print_status "INFO" "Enabling myMCPs services..."
sudo systemctl enable mymcp.service
sudo systemctl enable mymcp-watchdog.service

# Check service status
print_status "INFO" "Checking service status..."
if sudo systemctl is-enabled mymcp.service > /dev/null 2>&1; then
    print_status "PASS" "myMCPs service is enabled for auto-start"
else
    print_status "FAIL" "Failed to enable myMCPs service"
    exit 1
fi

if sudo systemctl is-enabled mymcp-watchdog.service > /dev/null 2>&1; then
    print_status "PASS" "myMCPs watchdog service is enabled"
else
    print_status "FAIL" "Failed to enable myMCPs watchdog service"
    exit 1
fi

# Start the services
print_status "INFO" "Starting myMCPs services..."
sudo systemctl start mymcp.service
sudo systemctl start mymcp-watchdog.service

# Wait a moment for services to start
sleep 10

# Check if services are running
if sudo systemctl is-active mymcp.service > /dev/null 2>&1; then
    print_status "PASS" "myMCPs service started successfully"
else
    print_status "WARN" "myMCPs service may not have started properly"
fi

if sudo systemctl is-active mymcp-watchdog.service > /dev/null 2>&1; then
    print_status "PASS" "myMCPs watchdog service started successfully"
else
    print_status "WARN" "myMCPs watchdog service may not have started properly"
fi

# Check Docker services
if docker compose ps | grep -q "Up"; then
    print_status "PASS" "Docker services are running"
else
    print_status "WARN" "Docker services may not be running properly"
fi

# Show service status
print_status "INFO" "Service status:"
sudo systemctl status mymcp.service --no-pager -l
echo ""
sudo systemctl status mymcp-watchdog.service --no-pager -l

echo ""
echo "🎯 Installation Complete!"
echo ""
echo "📋 Service Information:"
echo "   Main Service: mymcp.service"
echo "   Watchdog Service: mymcp-watchdog.service"
echo "   Status: $(sudo systemctl is-active mymcp.service)"
echo "   Enabled: $(sudo systemctl is-enabled mymcp.service)"
echo "   Auto-restart: Enabled"
echo "   Boot-time startup: Enabled"
echo ""
echo "🔧 Management Commands:"
echo "   Start:    sudo systemctl start mymcp"
echo "   Stop:     sudo systemctl stop mymcp"
echo "   Restart:  sudo systemctl restart mymcp"
echo "   Status:   sudo systemctl status mymcp"
echo "   Logs:     sudo journalctl -u mymcp -f"
echo "   Watchdog: sudo systemctl status mymcp-watchdog"
echo ""
echo "🚀 Auto-start is now configured!"
echo "   The myMCPs services will automatically:"
echo "   - Start on system boot (before login)"
echo "   - Restart automatically if they fail"
echo "   - Be monitored by watchdog service"
echo "   - Continue running even when logged out"
echo ""
echo "📚 Next Steps:"
echo "   1. Reboot your system to test auto-start"
echo "   2. Check service status after reboot: sudo systemctl status mymcp"
echo "   3. Verify MCP services are running: docker compose ps"
echo "   4. Test auto-restart by stopping services manually"
echo ""
echo "🔗 Repository: https://github.com/albisher/myMCPs"
