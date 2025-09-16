#!/bin/bash

# Setup MCP Services for Other Projects
# Production-ready, no workarounds

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <project-path>"
    echo "Example: $0 /home/a/Documents/Projects/myProject"
    exit 1
fi

PROJECT_PATH="$1"

if [ ! -d "$PROJECT_PATH" ]; then
    echo "Error: Project path does not exist: $PROJECT_PATH"
    exit 1
fi

echo "Setting up MCP services for: $PROJECT_PATH"

# Create .cursor directory if it doesn't exist
mkdir -p "$PROJECT_PATH/.cursor"

# Copy MCP configuration
cp .cursor/mcp.json "$PROJECT_PATH/.cursor/mcp.json"
echo "✓ MCP configuration copied"

# Copy environment file
cp .env "$PROJECT_PATH/.env"
echo "✓ Environment configuration copied"

echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo "To use MCP services in this project:"
echo "1. Open the project in Cursor IDE"
echo "2. Restart Cursor IDE to load MCP configuration"
echo "3. Use MCP tools via Cursor's interface"
echo ""
echo "Available MCP services:"
echo "- GitHub: Repository management, issues, PRs"
echo "- PostgreSQL: Database operations, queries"
echo "- Perplexity: AI research, question answering"
echo "- Local Search: File and content search"
echo "=========================================="
