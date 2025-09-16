#!/bin/bash

# Copy .env file from myMCPs project to another project
# Usage: ./copy-env-to-project.sh /path/to/project

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

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MYMCPS_DIR="$(dirname "$SCRIPT_DIR")"

# Check if .env file exists in myMCPs project
ENV_SOURCE="$MYMCPS_DIR/.env"
if [ ! -f "$ENV_SOURCE" ]; then
    print_error ".env file not found in myMCPs project: $ENV_SOURCE"
    print_error "Please create .env file first by copying from env.example"
    exit 1
fi

# Target .env file
ENV_TARGET="$PROJECT_PATH/.env"

print_status "Copying .env file from myMCPs project to: $PROJECT_PATH"

# Copy .env file
cp "$ENV_SOURCE" "$ENV_TARGET"
print_success "Copied .env file to: $ENV_TARGET"

# Check if .gitignore exists and add .env if needed
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

print_success "Environment configuration complete for project: $PROJECT_PATH"
print_status "The project now uses the same API keys and database configuration as myMCPs"
