# Local Search MCP - Quick Reference

## 🚀 Quick Start

After restarting Cursor IDE, you can use these tools from any project to search across your entire system.

## 📁 Search Any Directory

All tools accept a `directory` parameter to search specific locations:

```bash
# Search in specific project
search_files("component", directory="/home/a/Documents/Projects/myReactApp")

# Search across all projects
search_content("useState", directory="/home/a/Documents/Projects")

# Search entire home directory
find_files(file_types=[".py"], directory="/home/a")
```

## 🔍 Essential Commands

### Find Files
```bash
# Find files by name
search_files("config", directory="/home/a/Documents/Projects")

# Find files by type
search_files("test", file_types=[".js", ".py", ".ts"], limit=10)

# Find large files
find_files(min_size=1048576, directory="/home/a/Documents/Projects")
```

### Search Content
```bash
# Search for text
search_content("function", directory="/home/a/Documents/Projects")

# Search with file pattern
search_content("import", file_pattern="*.{js,ts,jsx,tsx}")

# Case-sensitive search
search_content("API_KEY", case_sensitive=true)
```

### Regex Search
```bash
# Find class definitions
search_regex("class\\s+\\w+", file_pattern="*.py")

# Find React components
search_regex("const\\s+\\w+\\s*=", file_pattern="*.{js,jsx,ts,tsx}")

# Find email addresses
search_regex("[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}")
```

## 🎯 Common Use Cases

### Cross-Project Search
```bash
# Find all React components
search_files("component", file_types=[".jsx", ".tsx"], directory="/home/a/Documents/Projects")

# Find all API calls
search_content("fetch\\(|axios\\.", directory="/home/a/Documents/Projects", file_pattern="*.{js,ts}")

# Find all TODO comments
search_content("TODO|FIXME", directory="/home/a/Documents/Projects", case_sensitive=false)
```

### Project Discovery
```bash
# Find all package.json files
search_files("package.json", directory="/home/a/Documents/Projects")

# Find all Python projects
find_files(file_types=[".py"], directory="/home/a/Documents/Projects", limit=20)

# Find all Docker projects
search_files("Dockerfile", directory="/home/a/Documents/Projects")
```

### Security & Quality
```bash
# Find potential secrets
search_content("password|secret|key", directory="/home/a/Documents/Projects", case_sensitive=false)

# Find console.log statements
search_content("console\\.log", directory="/home/a/Documents/Projects", file_pattern="*.{js,ts}")

# Find hardcoded URLs
search_regex("https?://[^\\s'\"]+", directory="/home/a/Documents/Projects")
```

## ⚡ Performance Tips

1. **Always use file patterns**: `file_pattern="*.{js,ts,py}"`
2. **Specify directories**: `directory="/home/a/Documents/Projects"`
3. **Limit results**: `limit=20`
4. **Use file types**: `file_types=[".js", ".ts"]`

## 🛠️ All Available Tools

| Tool | Purpose | Key Parameters |
|------|---------|----------------|
| `search_files` | Find files by name | `query`, `directory`, `file_types`, `limit` |
| `search_content` | Search file contents | `query`, `directory`, `file_pattern`, `case_sensitive` |
| `search_regex` | Regex pattern search | `pattern`, `directory`, `file_pattern`, `limit` |
| `find_files` | Advanced file finding | `directory`, `name_pattern`, `min_size`, `max_size`, `file_types` |
| `get_file_info` | File details | `file_path` |
| `watch_directory` | Monitor changes | `directory`, `recursive` |

## 📋 Parameter Reference

### Common Parameters
- `directory`: Path to search in (default: current workspace)
- `limit`: Maximum results (default: varies by tool)
- `file_pattern`: File pattern like `"*.{js,ts,py}"`
- `file_types`: Array like `[".js", ".ts", ".py"]`
- `case_sensitive`: Boolean for case sensitivity
- `whole_word`: Boolean for whole word matching

### File Finding Parameters
- `name_pattern`: File name pattern like `"*test*"`
- `min_size`: Minimum file size in bytes
- `max_size`: Maximum file size in bytes

## 🔧 Configuration

The local search MCP is configured to access your entire home directory (`/home/a`), so you can search any project or file from any Cursor IDE workspace.

## 💡 Pro Tips

1. **Combine tools**: Use `search_files` to find files, then `search_content` to search within them
2. **Use regex**: For complex patterns, use `search_regex` instead of `search_content`
3. **Start broad, then narrow**: Begin with directory search, then add file patterns
4. **Save common searches**: Create aliases or scripts for frequently used searches

## 🚨 Troubleshooting

- **Slow performance**: Add file patterns and directory limits
- **Too many results**: Use `limit` parameter and file type filters
- **Permission errors**: Check directory access permissions
- **No results**: Verify directory path and file patterns

---

**Ready to search!** Restart Cursor IDE and start using these powerful search tools across all your projects.
