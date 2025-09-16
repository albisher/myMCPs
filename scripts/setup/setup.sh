#!/bin/bash

# myMCPs Setup Script
# This script sets up the Docker MCP servers environment

set -e

echo "🚀 Setting up myMCPs Docker MCP Servers..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop and try again."
    exit 1
fi

# Check if Docker Compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose and try again."
    exit 1
fi

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp env.example .env
    echo "⚠️  Please edit .env file with your actual API keys and credentials before running docker-compose up"
    echo "   Required: GITHUB_PERSONAL_ACCESS_TOKEN, PERPLEXITY_API_KEY (optional)"
    echo "   Database: POSTGRES_HOST, POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD"
fi

# Pull latest MCP server images
echo "📥 Pulling latest MCP server images..."
docker pull mcp/github-mcp-server:latest
docker pull mcp/postgres:latest
docker pull mcp/perplexity-ask:latest

# Create Docker network
echo "🌐 Creating Docker network..."
docker network create mymcp-network 2>/dev/null || echo "Network already exists"

# Start services
echo "🚀 Starting MCP servers..."
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check service health
echo "🔍 Checking service health..."
docker-compose ps

echo ""
echo "✅ Setup complete!"
echo ""
echo "📋 Service Status:"
echo "   GitHub MCP Server:    http://localhost:8081"
echo "   PostgreSQL MCP Server: http://localhost:8082"
echo "   Perplexity MCP Server: http://localhost:8083"
echo ""
echo "🔧 Next steps:"
echo "   1. Edit .env file with your API keys"
echo "   2. Copy .cursor/mcp.json to your Cursor IDE configuration"
echo "   3. Restart Cursor IDE"
echo "   4. Test MCP integration"
echo ""
echo "📚 For more information, see docs/setup-guide.md"
