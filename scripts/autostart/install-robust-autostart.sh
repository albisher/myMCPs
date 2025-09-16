#!/bin/bash

# myMCPs Robust Auto-start Installation Script
# This script installs user systemd service with lingering and auto-restart capabilities

set -e

echo "🚀 Installing myMCPs Robust Auto-start Service..."

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

print_status "INFO" "Installing robust auto-start for user: $CURRENT_USER"
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

# Create the main service file with auto-restart capabilities
print_status "INFO" "Creating main service file with auto-restart..."

cat > "$USER_SYSTEMD_DIR/mymcp.service" << EOF
[Unit]
Description=myMCPs Docker Compose Services
After=graphical-session.target
Wants=graphical-session.target
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
Environment=HOME=$HOME
Environment=USER=$CURRENT_USER
Restart=always
RestartSec=10
RestartPreventExitStatus=0

[Install]
WantedBy=default.target
EOF

print_status "PASS" "Main service file created with auto-restart"

# Create a watchdog service for additional monitoring
print_status "INFO" "Creating watchdog service..."

cat > "$USER_SYSTEMD_DIR/mymcp-watchdog.service" << EOF
[Unit]
Description=myMCPs Docker Services Watchdog
Requires=mymcp.service
After=mymcp.service
StartLimitInterval=0

[Service]
Type=simple
WorkingDirectory=$PROJECT_DIR
ExecStart=/bin/bash -c 'while true; do if ! docker compose ps | grep -q "Up"; then echo "Services down, restarting..."; docker compose up -d; fi; sleep 30; done'
Environment=HOME=$HOME
Environment=USER=$CURRENT_USER
Restart=always
RestartSec=30

[Install]
WantedBy=default.target
EOF

print_status "PASS" "Watchdog service created"

# Create a health check service
print_status "INFO" "Creating health check service..."

cat > "$USER_SYSTEMD_DIR/mymcp-health.service" << EOF
[Unit]
Description=myMCPs Health Check Service
Requires=mymcp.service
After=mymcp.service
StartLimitInterval=0

[Service]
Type=simple
WorkingDirectory=$PROJECT_DIR
ExecStart=/bin/bash -c 'while true; do ./scripts/health-check.sh > /dev/null 2>&1 || echo "Health check failed"; sleep 60; done'
Environment=HOME=$HOME
Environment=USER=$CURRENT_USER
Restart=always
RestartSec=60

[Install]
WantedBy=default.target
EOF

print_status "PASS" "Health check service created"

# Reload user systemd daemon
print_status "INFO" "Reloading user systemd daemon..."
systemctl --user daemon-reload

# Enable the services
print_status "INFO" "Enabling myMCPs services..."
systemctl --user enable mymcp.service
systemctl --user enable mymcp-watchdog.service
systemctl --user enable mymcp-health.service

# Check service status
print_status "INFO" "Checking service status..."
if systemctl --user is-enabled mymcp.service > /dev/null 2>&1; then
    print_status "PASS" "myMCPs service is enabled for auto-start"
else
    print_status "FAIL" "Failed to enable myMCPs service"
    exit 1
fi

if systemctl --user is-enabled mymcp-watchdog.service > /dev/null 2>&1; then
    print_status "PASS" "myMCPs watchdog service is enabled"
else
    print_status "FAIL" "Failed to enable myMCPs watchdog service"
    exit 1
fi

if systemctl --user is-enabled mymcp-health.service > /dev/null 2>&1; then
    print_status "PASS" "myMCPs health check service is enabled"
else
    print_status "FAIL" "Failed to enable myMCPs health check service"
    exit 1
fi

# Start the services
print_status "INFO" "Starting myMCPs services..."
systemctl --user start mymcp.service
systemctl --user start mymcp-watchdog.service
systemctl --user start mymcp-health.service

# Wait a moment for services to start
sleep 10

# Check if services are running
if systemctl --user is-active mymcp.service > /dev/null 2>&1; then
    print_status "PASS" "myMCPs service started successfully"
else
    print_status "WARN" "myMCPs service may not have started properly"
fi

if systemctl --user is-active mymcp-watchdog.service > /dev/null 2>&1; then
    print_status "PASS" "myMCPs watchdog service started successfully"
else
    print_status "WARN" "myMCPs watchdog service may not have started properly"
fi

if systemctl --user is-active mymcp-health.service > /dev/null 2>&1; then
    print_status "PASS" "myMCPs health check service started successfully"
else
    print_status "WARN" "myMCPs health check service may not have started properly"
fi

# Check Docker services
if docker compose ps | grep -q "Up"; then
    print_status "PASS" "Docker services are running"
else
    print_status "WARN" "Docker services may not be running properly"
fi

# Show service status
print_status "INFO" "Service status:"
systemctl --user status mymcp.service --no-pager -l
echo ""
systemctl --user status mymcp-watchdog.service --no-pager -l
echo ""
systemctl --user status mymcp-health.service --no-pager -l

echo ""
echo "🎯 Installation Complete!"
echo ""
echo "📋 Service Information:"
echo "   Main Service: mymcp.service"
echo "   Watchdog Service: mymcp-watchdog.service"
echo "   Health Check Service: mymcp-health.service"
echo "   Status: $(systemctl --user is-active mymcp.service)"
echo "   Enabled: $(systemctl --user is-enabled mymcp.service)"
echo "   Auto-restart: Enabled"
echo "   Boot-time startup: Requires lingering"
echo ""
echo "🔧 Management Commands:"
echo "   Start:    systemctl --user start mymcp"
echo "   Stop:     systemctl --user stop mymcp"
echo "   Restart:  systemctl --user restart mymcp"
echo "   Status:   systemctl --user status mymcp"
echo "   Logs:     journalctl --user -u mymcp -f"
echo "   Watchdog: systemctl --user status mymcp-watchdog"
echo "   Health:   systemctl --user status mymcp-health"
echo ""
echo "🚀 Auto-start is now configured!"
echo "   The myMCPs services will automatically:"
echo "   - Start when you log in"
echo "   - Restart automatically if they fail"
echo "   - Be monitored by watchdog service"
echo "   - Have health checks every minute"
echo ""
echo "💡 To enable boot-time startup (before login):"
echo "   sudo loginctl enable-linger $CURRENT_USER"
echo ""
echo "📚 Next Steps:"
echo "   1. Enable lingering for boot-time startup (optional)"
echo "   2. Reboot your system to test auto-start"
echo "   3. Check service status after reboot"
echo "   4. Verify MCP services are running"
echo "   5. Test auto-restart by stopping services manually"
echo ""
echo "🔗 Repository: https://github.com/albisher/myMCPs"
