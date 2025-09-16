#!/bin/bash

# myMCPs Services Startup Script
# This script ensures MCP services are running with proper error handling

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "Starting myMCPs services..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Docker is not running. Waiting for Docker to start..."
    while ! docker info > /dev/null 2>&1; do
        sleep 5
    done
    echo "Docker is now running."
fi

# Start services
echo "Starting Docker Compose services..."
docker compose up -d

# Wait for services to be ready
echo "Waiting for services to be ready..."
sleep 10

# Check if services are running
if docker compose ps | grep -q "Up"; then
    echo "Services started successfully."
else
    echo "Warning: Some services may not be running properly."
    docker compose ps
fi

# Keep the script running to maintain the service
echo "Services are running. Monitoring..."
while true; do
    # Check if services are still running
    if ! docker compose ps | grep -q "Up"; then
        echo "Services stopped, restarting..."
        docker compose up -d
    fi
    sleep 30
done
