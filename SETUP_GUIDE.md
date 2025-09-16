# MCP Services Setup Guide

## 🚀 **Quick Setup**

### **1. Clone the Repository**
```bash
git clone <repository-url>
cd myMCPs
```

### **2. Configure Environment Variables**
```bash
# Copy the environment template
cp env.example .env

# Edit the .env file with your actual credentials
nano .env
```

### **3. Configure MCP Services**
```bash
# Copy the MCP configuration template
cp .cursor/mcp.json.sample .cursor/mcp.json

# Edit the MCP configuration with your credentials
nano .cursor/mcp.json
```

### **4. Get Your API Keys**

#### **GitHub Personal Access Token**
1. Go to [GitHub Settings > Developer settings > Personal access tokens](https://github.com/settings/tokens)
2. Click "Generate new token (classic)"
3. Select scopes: `repo`, `read:org`, `read:user`, `read:project`
4. Copy the generated token

#### **Perplexity API Key**
1. Go to [Perplexity AI Settings > API](https://www.perplexity.ai/settings/api)
2. Generate a new API key
3. Copy the generated key

#### **PostgreSQL Database**
1. Set up a PostgreSQL database
2. Note the connection details:
   - Host: `localhost` (or your database host)
   - Port: `5432` (default)
   - Database name
   - Username
   - Password

### **5. Update Configuration Files**

#### **Update `.env` file:**
```bash
# GitHub MCP Server Configuration
GITHUB_PERSONAL_ACCESS_TOKEN=your_actual_github_token_here

# PostgreSQL MCP Server Configuration
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=your_database_name
POSTGRES_USER=your_database_user
POSTGRES_PASSWORD=your_database_password

# Perplexity MCP Server Configuration
PERPLEXITY_API_KEY=your_actual_perplexity_api_key_here
```

#### **Update `.cursor/mcp.json` file:**
Replace the placeholder values in the sample configuration with your actual credentials.

### **6. Test the Setup**
```bash
# Run the production test
./scripts/testing/test-mcp-production.sh

# Run the simple test
./scripts/testing/test-mcp-simple.sh
```

### **7. Use in Cursor IDE**
1. Open Cursor IDE
2. Open any project
3. Use MCP tools via Cursor's interface

## 🔧 **Configuration Details**

### **Required API Keys:**
- **GitHub**: Personal access token with repo, read:org, read:user, read:project scopes
- **Perplexity**: API key from Perplexity AI settings
- **PostgreSQL**: Database connection details

### **Optional Configuration:**
- **Custom ports**: Modify port numbers in configuration files
- **Custom search paths**: Update SEARCH_ROOT in local-search configuration
- **Custom user IDs**: Update user ID in local-search configuration

## 🛡️ **Security Notes**

- **Never commit** `.env` or `.cursor/mcp.json` files to version control
- **Use strong passwords** for database connections
- **Rotate API keys** regularly
- **Limit API key scopes** to minimum required permissions

## 📋 **Troubleshooting**

### **Common Issues:**
1. **API authentication failed**: Check if API keys are correct and have proper scopes
2. **Database connection failed**: Verify database credentials and connectivity
3. **MCP services not working**: Restart Cursor IDE to reload configuration

### **Test Commands:**
```bash
# Test all services
./scripts/testing/test-mcp-production.sh

# Test individual services
./scripts/testing/test-mcp-simple.sh

# Check Docker images
docker images | grep mcp
```

## 🎯 **Next Steps**

After setup:
1. **Test all services** using the provided test scripts
2. **Use MCP tools** in Cursor IDE
3. **Set up for other projects** using `./scripts/production/setup-other-project.sh`
4. **Read the documentation** in `docs/` directory

## 📚 **Documentation**

- **[Production Guide](docs/guides/PRODUCTION_GUIDE.md)** - Complete usage guide
- **[Production Summary](docs/guides/PRODUCTION_SUMMARY.md)** - Quick reference
- **[Documentation Index](docs/README.md)** - All documentation

---

**Ready to use MCP services with your own credentials!**
