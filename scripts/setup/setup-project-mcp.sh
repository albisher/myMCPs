#!/bin/bash

# Setup MCP configuration for a new project
# Usage: ./setup-project-mcp.sh /path/to/project

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if project path is provided
if [ $# -eq 0 ]; then
    print_error "Usage: $0 <project_path>"
    print_error "Example: $0 /home/a/Documents/Projects/myNewProject"
    exit 1
fi

PROJECT_PATH="$1"

# Check if project path exists
if [ ! -d "$PROJECT_PATH" ]; then
    print_error "Project path does not exist: $PROJECT_PATH"
    exit 1
fi

print_status "Setting up MCP configuration for project: $PROJECT_PATH"

# Create .cursor directory if it doesn't exist
CURSOR_DIR="$PROJECT_PATH/.cursor"
if [ ! -d "$CURSOR_DIR" ]; then
    print_status "Creating .cursor directory..."
    mkdir -p "$CURSOR_DIR"
    print_success "Created .cursor directory"
else
    print_status ".cursor directory already exists"
fi

# Create mcp.json configuration
MCP_CONFIG="$CURSOR_DIR/mcp.json"
print_status "Creating MCP configuration..."

cat > "$MCP_CONFIG" << 'EOF'
{
  "mcpServers": {
    "github": {
      "command": "docker",
      "args": [
        "run",
        "-i",
        "--rm",
        "--env-file",
        ".env",
        "mcp/github-mcp-server:latest"
      ]
    },
    "postgres": {
      "command": "docker",
      "args": [
        "run",
        "-i",
        "--rm",
        "--env-file",
        ".env",
        "mcp/postgres:latest",
        "postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}"
      ]
    },
    "perplexity": {
      "command": "docker",
      "args": [
        "run",
        "-i",
        "--rm",
        "--env-file",
        ".env",
        "mcp/perplexity-ask:latest"
      ]
    },
    "local-search": {
      "command": "docker",
      "args": [
        "run",
        "-i",
        "--rm",
        "--user",
        "1000:1000",
        "-v",
        "/home/a:/home/a",
        "-e",
        "SEARCH_ROOT=/home/a",
        "mymcps-mcp-local-search"
      ]
    }
  }
}
EOF

print_success "Created MCP configuration: $MCP_CONFIG"

# Create .env file if it doesn't exist
ENV_FILE="$PROJECT_PATH/.env"
if [ ! -f "$ENV_FILE" ]; then
    print_status "Creating .env file..."
    cat > "$ENV_FILE" << 'EOF'
# GitHub API
GITHUB_PERSONAL_ACCESS_TOKEN=your_github_token

# Perplexity API  
PERPLEXITY_API_KEY=your_perplexity_key

# PostgreSQL (if using)
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=mymcp_db
POSTGRES_USER=mymcp_user
POSTGRES_PASSWORD=mymcp_pass
EOF
    print_success "Created .env file: $ENV_FILE"
    print_warning "Please update the API keys in .env file with your actual values"
else
    print_status ".env file already exists"
    print_warning "Please ensure your API keys are configured in .env file"
fi

# Create .gitignore entry for .env if it doesn't exist
GITIGNORE="$PROJECT_PATH/.gitignore"
if [ -f "$GITIGNORE" ]; then
    if ! grep -q "\.env" "$GITIGNORE"; then
        print_status "Adding .env to .gitignore..."
        echo "" >> "$GITIGNORE"
        echo "# Environment variables" >> "$GITIGNORE"
        echo ".env" >> "$GITIGNORE"
        print_success "Added .env to .gitignore"
    else
        print_status ".env already in .gitignore"
    fi
else
    print_status "Creating .gitignore with .env entry..."
    cat > "$GITIGNORE" << 'EOF'
# Environment variables
.env

# Node modules
node_modules/

# Python
__pycache__/
*.pyc
*.pyo
*.pyd
.Python
env/
venv/
.venv/

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db
EOF
    print_success "Created .gitignore with .env entry"
fi

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    print_warning "Docker is not running. Please start Docker before using MCP services."
fi

# Check if MCP images are available
print_status "Checking MCP Docker images..."

MISSING_IMAGES=()

if ! docker image inspect mcp/github-mcp-server:latest >/dev/null 2>&1; then
    MISSING_IMAGES+=("mcp/github-mcp-server:latest")
fi

if ! docker image inspect mcp/postgres:latest >/dev/null 2>&1; then
    MISSING_IMAGES+=("mcp/postgres:latest")
fi

if ! docker image inspect mcp/perplexity-ask:latest >/dev/null 2>&1; then
    MISSING_IMAGES+=("mcp/perplexity-ask:latest")
fi

if ! docker image inspect mymcps-mcp-local-search >/dev/null 2>&1; then
    MISSING_IMAGES+=("mymcps-mcp-local-search")
fi

if [ ${#MISSING_IMAGES[@]} -gt 0 ]; then
    print_warning "Missing Docker images:"
    for image in "${MISSING_IMAGES[@]}"; do
        echo "  - $image"
    done
    print_status "Run 'docker-compose pull' in the myMCPs project to download missing images"
else
    print_success "All MCP Docker images are available"
fi

# Final instructions
echo ""
print_success "MCP configuration setup complete for project: $PROJECT_PATH"
echo ""
print_status "Next steps:"
echo "1. Update API keys in .env file:"
echo "   - GITHUB_PERSONAL_ACCESS_TOKEN"
echo "   - PERPLEXITY_API_KEY"
echo ""
echo "2. Restart Cursor IDE to load the new MCP configuration"
echo ""
print_status "Available MCP services:"
echo "  - github: GitHub repository management"
echo "  - postgres: PostgreSQL database queries"
echo "  - perplexity: Real-time research"
echo "  - local-search: Cross-project file and content search"
echo ""
print_status "Usage examples:"
echo "  - search_files('component', directory='/home/a/Documents/Projects')"
echo "  - search_content('useState', directory='$PROJECT_PATH')"
echo "  - find_files(file_types=['.py'], directory='/home/a/Documents/Projects')"
