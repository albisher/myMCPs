# Local Search MCP Usage Guide

## Overview

The local search MCP server provides powerful search capabilities across your entire system. With the updated configuration, you can now search any directory in your home folder (`/home/a`) from any Cursor IDE project.

## Configuration

The local search MCP is configured to access your entire home directory:
- **Mount**: `/home/a:/home/a` (full home directory access)
- **Search Root**: `/home/a` (can search anywhere in your home directory)
- **Default Directory**: Current workspace (when no directory specified)

## Available Tools

### 1. `search_files` - Find Files by Name

Search for files by name using fuzzy matching.

**Basic Usage:**
```bash
# Search for files containing "config" in current project
search_files("config")

# Search in specific project directory
search_files("component", directory="/home/a/Documents/Projects/myReactApp")

# Search with file type filter
search_files("test", file_types=[".js", ".ts", ".py"], limit=10)

# Search in multiple project types
search_files("api", directory="/home/a/Documents/Projects", limit=20)
```

**Real Examples:**
```bash
# Find all React components
search_files("component", directory="/home/a/Documents/Projects", file_types=[".jsx", ".tsx"])

# Find configuration files across all projects
search_files("config", directory="/home/a/Documents/Projects", file_types=[".json", ".yaml", ".yml", ".toml"])

# Find test files
search_files("test", directory="/home/a/Documents/Projects", file_types=[".js", ".ts", ".py", ".go"])
```

### 2. `search_content` - Search File Contents

Search for text content within files.

**Basic Usage:**
```bash
# Search for "function" in current project
search_content("function")

# Search in specific project
search_content("useState", directory="/home/a/Documents/Projects/myReactApp")

# Search with file pattern
search_content("import", file_pattern="*.{js,ts,jsx,tsx}", directory="/home/a/Documents/Projects")

# Case-sensitive search
search_content("API_KEY", case_sensitive=true, directory="/home/a/Documents/Projects")
```

**Real Examples:**
```bash
# Find all React hooks usage
search_content("useState|useEffect|useContext", directory="/home/a/Documents/Projects", file_pattern="*.{js,jsx,ts,tsx}")

# Find database queries
search_content("SELECT|INSERT|UPDATE|DELETE", directory="/home/a/Documents/Projects", file_pattern="*.{sql,py,js}")

# Find TODO comments across all projects
search_content("TODO|FIXME|HACK", directory="/home/a/Documents/Projects", case_sensitive=false)

# Find API endpoints
search_content("app\\.get|app\\.post|app\\.put|app\\.delete", directory="/home/a/Documents/Projects", file_pattern="*.{js,py,go}")
```

### 3. `search_regex` - Regular Expression Search

Search using regular expressions for complex patterns.

**Basic Usage:**
```bash
# Find class definitions
search_regex("class\\s+\\w+", directory="/home/a/Documents/Projects", file_pattern="*.py")

# Find function definitions
search_regex("function\\s+\\w+", directory="/home/a/Documents/Projects", file_pattern="*.{js,ts}")

# Find email addresses
search_regex("[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}", directory="/home/a/Documents/Projects")
```

**Real Examples:**
```bash
# Find all React components
search_regex("const\\s+\\w+\\s*=\\s*\\([^)]*\\)\\s*=>", directory="/home/a/Documents/Projects", file_pattern="*.{js,jsx,ts,tsx}")

# Find Python class methods
search_regex("def\\s+\\w+\\s*\\(", directory="/home/a/Documents/Projects", file_pattern="*.py")

# Find JavaScript imports
search_regex("import\\s+.*\\s+from\\s+['\"][^'\"]+['\"]", directory="/home/a/Documents/Projects", file_pattern="*.{js,ts,jsx,tsx}")

# Find configuration values
search_regex("\\w+\\s*[:=]\\s*['\"][^'\"]+['\"]", directory="/home/a/Documents/Projects", file_pattern="*.{json,yaml,yml,env}")
```

### 4. `find_files` - Advanced File Finding

Find files by various criteria (size, date, type, etc.).

**Basic Usage:**
```bash
# Find large files (>1MB)
find_files(min_size=1048576, directory="/home/a/Documents/Projects", limit=20)

# Find log files
find_files(name_pattern="*.log", directory="/home/a/Documents/Projects")

# Find files by type
find_files(file_types=[".py", ".js", ".ts"], directory="/home/a/Documents/Projects", limit=50)

# Find files in specific size range
find_files(min_size=1024, max_size=1048576, directory="/home/a/Documents/Projects")
```

**Real Examples:**
```bash
# Find all Python files
find_files(file_types=[".py"], directory="/home/a/Documents/Projects", limit=100)

# Find large media files
find_files(file_types=[".mp4", ".avi", ".mov", ".jpg", ".png"], min_size=10485760, directory="/home/a/Documents/Projects")

# Find recent files (by name pattern)
find_files(name_pattern="*2024*", directory="/home/a/Documents/Projects")

# Find configuration files
find_files(file_types=[".json", ".yaml", ".yml", ".toml", ".ini", ".conf"], directory="/home/a/Documents/Projects")
```

### 5. `get_file_info` - File Information

Get detailed information about a specific file.

**Basic Usage:**
```bash
# Get info about a specific file
get_file_info("/home/a/Documents/Projects/myApp/src/App.js")

# Get info about a config file
get_file_info("/home/a/Documents/Projects/myApp/package.json")
```

### 6. `watch_directory` - Directory Monitoring

Start watching a directory for changes.

**Basic Usage:**
```bash
# Watch a project directory
watch_directory("/home/a/Documents/Projects/myApp", recursive=true)

# Watch multiple projects
watch_directory("/home/a/Documents/Projects", recursive=true)
```

## Common Use Cases

### 1. Cross-Project Code Search

```bash
# Find all instances of a specific function across all projects
search_content("myFunction", directory="/home/a/Documents/Projects")

# Find all API calls
search_content("fetch\\(|axios\\.|request\\.", directory="/home/a/Documents/Projects", file_pattern="*.{js,ts,py}")

# Find all database models
search_content("class.*Model|def.*model", directory="/home/a/Documents/Projects", file_pattern="*.{py,js,ts}")
```

### 2. Project Discovery

```bash
# Find all React projects
search_files("package.json", directory="/home/a/Documents/Projects")
# Then search content for "react" in those directories

# Find all Python projects
find_files(file_types=[".py"], directory="/home/a/Documents/Projects", limit=10)
# Then check for requirements.txt or setup.py

# Find all Docker projects
search_files("Dockerfile", directory="/home/a/Documents/Projects")
```

### 3. Security and Code Quality

```bash
# Find potential security issues
search_content("password|secret|key|token", directory="/home/a/Documents/Projects", case_sensitive=false)

# Find hardcoded URLs
search_regex("https?://[^\\s'\"]+", directory="/home/a/Documents/Projects")

# Find console.log statements
search_content("console\\.log", directory="/home/a/Documents/Projects", file_pattern="*.{js,ts}")
```

### 4. Documentation and Comments

```bash
# Find all README files
search_files("README", directory="/home/a/Documents/Projects")

# Find all documentation
search_files("docs", directory="/home/a/Documents/Projects")

# Find all comments
search_content("//|#|/\\*", directory="/home/a/Documents/Projects")
```

## Performance Tips

### 1. Use File Patterns
Always use file patterns to limit search scope:
```bash
# Good - limits to specific file types
search_content("function", file_pattern="*.{js,ts,py}")

# Avoid - searches all files
search_content("function")
```

### 2. Use Directory Limits
Specify directories to avoid searching unnecessary locations:
```bash
# Good - searches only projects
search_content("import", directory="/home/a/Documents/Projects")

# Avoid - searches entire home directory
search_content("import")
```

### 3. Use Result Limits
Limit results to avoid overwhelming output:
```bash
# Good - limits results
search_files("test", limit=20)

# Avoid - might return hundreds of results
search_files("test")
```

### 4. Combine with File Types
Use file type filters for better performance:
```bash
# Good - specific file types
search_content("class", file_types=[".py", ".js", ".ts"])

# Avoid - searches all file types
search_content("class")
```

## Advanced Examples

### Find All Projects Using a Specific Library

```bash
# Step 1: Find all package.json files
search_files("package.json", directory="/home/a/Documents/Projects")

# Step 2: Search for specific library in those files
search_content("react-router", directory="/home/a/Documents/Projects", file_pattern="package.json")
```

### Find All API Endpoints

```bash
# Find Express.js routes
search_regex("app\\.(get|post|put|delete|patch)\\s*\\(['\"][^'\"]+['\"]", directory="/home/a/Documents/Projects", file_pattern="*.js")

# Find Flask routes
search_regex("@app\\.route\\s*\\(['\"][^'\"]+['\"]", directory="/home/a/Documents/Projects", file_pattern="*.py")
```

### Find All Database Queries

```bash
# Find SQL queries
search_content("SELECT|INSERT|UPDATE|DELETE", directory="/home/a/Documents/Projects", file_pattern="*.{sql,py,js,ts}")

# Find ORM queries
search_content("Model\\.|Query\\.|find|create|update|delete", directory="/home/a/Documents/Projects", file_pattern="*.{py,js,ts}")
```

## Troubleshooting

### Common Issues

1. **Permission Denied**
   - Ensure the directory is accessible
   - Check file permissions

2. **Slow Performance**
   - Use file patterns to limit scope
   - Specify directories instead of searching everything
   - Use result limits

3. **Too Many Results**
   - Add file type filters
   - Use more specific search terms
   - Limit the search directory

### Best Practices

1. **Start Specific**: Begin with specific directories and file types
2. **Use Patterns**: Leverage file patterns and regex for precision
3. **Limit Results**: Always use reasonable result limits
4. **Combine Tools**: Use multiple tools together for comprehensive searches

## Integration with Other MCPs

The local search MCP works great with other MCPs:

```bash
# Use local search to find files, then use GitHub MCP to check their history
# Use local search to find code, then use Perplexity MCP to research best practices
# Use local search to find database files, then use PostgreSQL MCP to query them
```

This powerful combination gives you comprehensive development capabilities across your entire system!
