# Environment Configuration Guide

## ✅ **Updated Configuration**

All MCP services now use the `.env` file for configuration instead of hardcoded values. This provides better security and easier management across projects.

## 🔧 **How It Works**

### **Main Configuration**
The `.cursor/mcp.json` now uses `--env-file .env` to load environment variables:

```json
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
```

### **Environment Variables**
The `.env` file contains all the configuration:

```bash
# GitHub MCP Server Configuration
GITHUB_PERSONAL_ACCESS_TOKEN=your_github_token_here

# PostgreSQL MCP Server Configuration
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=mymcp_db
POSTGRES_USER=mymcp_user
POSTGRES_PASSWORD=mymcp_pass

# Perplexity MCP Server Configuration
PERPLEXITY_API_KEY=your_perplexity_api_key_here
```

## 🚀 **Setting Up New Projects**

### **Method 1: Automated Setup (Recommended)**

Use the provided scripts to set up MCP configuration for new projects:

```bash
# Setup MCP configuration for a new project
./scripts/setup-project-mcp.sh /path/to/your/project

# Copy .env file from myMCPs to the project
./scripts/copy-env-to-project.sh /path/to/your/project
```

### **Method 2: Manual Setup**

1. **Create `.cursor/mcp.json`** in your project:
```bash
mkdir -p /path/to/your/project/.cursor
cp .cursor/mcp.json /path/to/your/project/.cursor/mcp.json
```

2. **Create `.env` file** in your project:
```bash
cp .env /path/to/your/project/.env
```

3. **Add `.env` to `.gitignore`**:
```bash
echo ".env" >> /path/to/your/project/.gitignore
```

## 🔑 **API Key Management**

### **Shared Configuration**
- All projects use the same API keys from the main `.env` file
- No need to manage multiple API keys
- Centralized configuration management

### **Project-Specific Configuration**
If you need different API keys for different projects:

1. **Copy the main `.env` file**:
```bash
cp /home/a/Documents/Projects/myMCPs/.env /path/to/your/project/.env
```

2. **Edit the project's `.env` file** with project-specific values:
```bash
# Project-specific GitHub token
GITHUB_PERSONAL_ACCESS_TOKEN=project_specific_github_token

# Project-specific Perplexity key
PERPLEXITY_API_KEY=project_specific_perplexity_key

# Project-specific database
POSTGRES_DB=project_specific_db
POSTGRES_USER=project_specific_user
POSTGRES_PASSWORD=project_specific_password
```

## 📋 **Benefits of .env Configuration**

### **Security**
- ✅ API keys are not hardcoded in configuration files
- ✅ `.env` files are excluded from version control
- ✅ Easy to manage different environments (dev, staging, prod)

### **Flexibility**
- ✅ Easy to change API keys without modifying configuration
- ✅ Support for different configurations per project
- ✅ Environment-specific settings

### **Maintenance**
- ✅ Centralized configuration management
- ✅ Easy to update across all projects
- ✅ Consistent configuration approach

## 🛠️ **Usage Examples**

### **Setup a New React Project**
```bash
# Create new project
mkdir /home/a/Documents/Projects/myReactApp
cd /home/a/Documents/Projects/myReactApp

# Setup MCP configuration
/home/a/Documents/Projects/myMCPs/scripts/setup-project-mcp.sh .

# Copy environment configuration
/home/a/Documents/Projects/myMCPs/scripts/copy-env-to-project.sh .
```

### **Setup a New Python Project**
```bash
# Create new project
mkdir /home/a/Documents/Projects/myPythonApp
cd /home/a/Documents/Projects/myPythonApp

# Setup MCP configuration
/home/a/Documents/Projects/myMCPs/scripts/setup-project-mcp.sh .

# Copy environment configuration
/home/a/Documents/Projects/myMCPs/scripts/copy-env-to-project.sh .
```

## 🔍 **Verification**

After setting up a project, verify the configuration:

1. **Check `.cursor/mcp.json` exists**:
```bash
ls -la /path/to/your/project/.cursor/mcp.json
```

2. **Check `.env` file exists**:
```bash
ls -la /path/to/your/project/.env
```

3. **Check `.gitignore` includes `.env`**:
```bash
grep "\.env" /path/to/your/project/.gitignore
```

4. **Restart Cursor IDE** to load the new configuration

## 🚨 **Troubleshooting**

### **Common Issues**

1. **API keys not working**:
   - Verify `.env` file exists and contains correct values
   - Check that `.env` file is in the project root
   - Ensure API keys are valid and have proper permissions

2. **Database connection issues**:
   - Verify PostgreSQL is running: `docker-compose ps`
   - Check database credentials in `.env` file
   - Ensure database exists and is accessible

3. **MCP services not loading**:
   - Restart Cursor IDE after configuration changes
   - Check `.cursor/mcp.json` syntax is valid
   - Verify Docker is running and images are available

### **Debug Commands**

```bash
# Check if .env file is being loaded
docker run --rm --env-file .env alpine env | grep -E "(GITHUB|PERPLEXITY|POSTGRES)"

# Test MCP service directly
docker run --rm --env-file .env mcp/github-mcp-server:latest

# Check Docker images
docker images | grep mcp
```

## 📚 **Related Documentation**

- [Setup Guide](docs/setup-guide.md) - Initial project setup
- [Local Search Usage Guide](LOCAL_SEARCH_USAGE_GUIDE.md) - Using local search across projects
- [Troubleshooting](docs/troubleshooting.md) - Common issues and solutions

## 🎉 **Ready to Use**

Your MCP services are now configured to use the `.env` file approach! This provides:

- ✅ **Better Security**: API keys not hardcoded
- ✅ **Easy Management**: Centralized configuration
- ✅ **Project Flexibility**: Easy to set up new projects
- ✅ **Environment Support**: Different configs for different environments

Simply update your `.env` file with your actual API keys and start using the MCP services across all your projects!
