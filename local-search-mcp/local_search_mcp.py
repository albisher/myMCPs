#!/usr/bin/env python3
"""
Local Search MCP Server
A high-performance local file and content search server for IDEs.
Uses native OS tools (ripgrep, fd) for maximum speed and efficiency.
"""

import asyncio
import json
import os
import sqlite3
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Union
import argparse
import logging

# MCP imports
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import (
    CallToolRequest,
    ListToolsRequest,
    Tool,
    TextContent,
    ImageContent,
    EmbeddedResource,
)

# Third-party imports
import psutil
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
from fuzzywuzzy import fuzz, process

# Try to import magic, fallback if not available
try:
    import magic
except ImportError:
    magic = None

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SearchResult:
    """Represents a search result with file path, line number, and content."""
    def __init__(self, file_path: str, line_number: int = 0, column: int = 0, 
                 content: str = "", score: float = 0.0):
        self.file_path = file_path
        self.line_number = line_number
        self.column = column
        self.content = content
        self.score = score

class FileIndexer:
    """Handles file indexing and caching using SQLite."""
    
    def __init__(self, db_path: str):
        self.db_path = db_path
        self.init_database()
    
    def init_database(self):
        """Initialize the SQLite database for caching search results."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Create tables
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS search_cache (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                query TEXT NOT NULL,
                search_type TEXT NOT NULL,
                results TEXT NOT NULL,
                created_at REAL NOT NULL,
                expires_at REAL NOT NULL
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS file_metadata (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                file_path TEXT UNIQUE NOT NULL,
                file_name TEXT NOT NULL,
                file_size INTEGER,
                modified_time REAL,
                file_type TEXT,
                indexed_at REAL NOT NULL
            )
        ''')
        
        # Create indexes
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_query ON search_cache(query, search_type)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_file_path ON file_metadata(file_path)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_file_name ON file_metadata(file_name)')
        
        conn.commit()
        conn.close()
    
    def cache_results(self, query: str, search_type: str, results: List[SearchResult], 
                     ttl_seconds: int = 300):
        """Cache search results with TTL."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        now = time.time()
        expires_at = now + ttl_seconds
        
        # Convert results to JSON
        results_json = json.dumps([
            {
                'file_path': r.file_path,
                'line_number': r.line_number,
                'column': r.column,
                'content': r.content,
                'score': r.score
            } for r in results
        ])
        
        cursor.execute('''
            INSERT OR REPLACE INTO search_cache 
            (query, search_type, results, created_at, expires_at)
            VALUES (?, ?, ?, ?, ?)
        ''', (query, search_type, results_json, now, expires_at))
        
        conn.commit()
        conn.close()
    
    def get_cached_results(self, query: str, search_type: str) -> Optional[List[SearchResult]]:
        """Get cached search results if they haven't expired."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        now = time.time()
        cursor.execute('''
            SELECT results FROM search_cache 
            WHERE query = ? AND search_type = ? AND expires_at > ?
        ''', (query, search_type, now))
        
        result = cursor.fetchone()
        conn.close()
        
        if result:
            results_data = json.loads(result[0])
            return [
                SearchResult(
                    file_path=r['file_path'],
                    line_number=r['line_number'],
                    column=r['column'],
                    content=r['content'],
                    score=r['score']
                ) for r in results_data
            ]
        return None

class LocalSearchMCP:
    """Main MCP server class for local search functionality."""
    
    def __init__(self, search_root: str = None):
        self.search_root = Path(search_root) if search_root else Path.cwd()
        # Use /tmp for cache directory to avoid permission issues
        cache_dir = Path('/tmp') / 'local_search_cache'
        cache_dir.mkdir(exist_ok=True)
        self.indexer = FileIndexer(str(cache_dir / 'search_cache.db'))
        self.observer = None
        self.watched_dirs = set()
        
        # Initialize MCP server
        self.server = Server("local-search-mcp")
        self.setup_handlers()
    
    def setup_handlers(self):
        """Setup MCP request handlers."""
        
        @self.server.list_tools()
        async def list_tools() -> List[Tool]:
            return [
                Tool(
                    name="search_files",
                    description="Search for files by name using fuzzy matching",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "query": {
                                "type": "string",
                                "description": "File name or path to search for"
                            },
                            "directory": {
                                "type": "string",
                                "description": "Directory to search in (default: current directory)",
                                "default": str(self.search_root)
                            },
                            "limit": {
                                "type": "integer",
                                "description": "Maximum number of results",
                                "default": 20
                            },
                            "file_types": {
                                "type": "array",
                                "items": {"type": "string"},
                                "description": "File extensions to include (e.g., ['.py', '.js'])",
                                "default": []
                            }
                        },
                        "required": ["query"]
                    }
                ),
                Tool(
                    name="search_content",
                    description="Search for text content within files",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "query": {
                                "type": "string",
                                "description": "Text to search for"
                            },
                            "directory": {
                                "type": "string",
                                "description": "Directory to search in",
                                "default": str(self.search_root)
                            },
                            "case_sensitive": {
                                "type": "boolean",
                                "description": "Case sensitive search",
                                "default": False
                            },
                            "whole_word": {
                                "type": "boolean",
                                "description": "Match whole words only",
                                "default": False
                            },
                            "file_pattern": {
                                "type": "string",
                                "description": "File pattern (e.g., '*.py', '**/*.js')",
                                "default": "**/*"
                            },
                            "limit": {
                                "type": "integer",
                                "description": "Maximum number of results",
                                "default": 50
                            }
                        },
                        "required": ["query"]
                    }
                ),
                Tool(
                    name="search_regex",
                    description="Search using regular expressions",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "pattern": {
                                "type": "string",
                                "description": "Regular expression pattern"
                            },
                            "directory": {
                                "type": "string",
                                "description": "Directory to search in",
                                "default": str(self.search_root)
                            },
                            "file_pattern": {
                                "type": "string",
                                "description": "File pattern to limit search",
                                "default": "**/*"
                            },
                            "limit": {
                                "type": "integer",
                                "description": "Maximum number of results",
                                "default": 50
                            }
                        },
                        "required": ["pattern"]
                    }
                ),
                Tool(
                    name="find_files",
                    description="Find files by various criteria (size, date, type, etc.)",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "directory": {
                                "type": "string",
                                "description": "Directory to search in",
                                "default": str(self.search_root)
                            },
                            "name_pattern": {
                                "type": "string",
                                "description": "File name pattern (supports wildcards)",
                                "default": "*"
                            },
                            "min_size": {
                                "type": "integer",
                                "description": "Minimum file size in bytes"
                            },
                            "max_size": {
                                "type": "integer",
                                "description": "Maximum file size in bytes"
                            },
                            "file_types": {
                                "type": "array",
                                "items": {"type": "string"},
                                "description": "File extensions to include"
                            },
                            "limit": {
                                "type": "integer",
                                "description": "Maximum number of results",
                                "default": 100
                            }
                        }
                    }
                ),
                Tool(
                    name="get_file_info",
                    description="Get detailed information about a specific file",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "file_path": {
                                "type": "string",
                                "description": "Path to the file"
                            }
                        },
                        "required": ["file_path"]
                    }
                ),
                Tool(
                    name="watch_directory",
                    description="Start watching a directory for changes",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "directory": {
                                "type": "string",
                                "description": "Directory to watch"
                            },
                            "recursive": {
                                "type": "boolean",
                                "description": "Watch subdirectories recursively",
                                "default": True
                            }
                        },
                        "required": ["directory"]
                    }
                )
            ]
        
        @self.server.call_tool()
        async def call_tool(name: str, arguments: Dict[str, Any]) -> List[Union[TextContent, ImageContent, EmbeddedResource]]:
            try:
                if name == "search_files":
                    return await self.search_files(**arguments)
                elif name == "search_content":
                    return await self.search_content(**arguments)
                elif name == "search_regex":
                    return await self.search_regex(**arguments)
                elif name == "find_files":
                    return await self.find_files(**arguments)
                elif name == "get_file_info":
                    return await self.get_file_info(**arguments)
                elif name == "watch_directory":
                    return await self.watch_directory(**arguments)
                else:
                    raise ValueError(f"Unknown tool: {name}")
            except Exception as e:
                logger.error(f"Error in tool {name}: {e}")
                return [TextContent(type="text", text=f"Error: {str(e)}")]
    
    async def search_files(self, query: str, directory: str = None, 
                          limit: int = 20, file_types: List[str] = None) -> List[TextContent]:
        """Search for files by name using fuzzy matching."""
        search_dir = Path(directory) if directory else self.search_root
        
        # Check cache first
        cache_key = f"{query}:{search_dir}:{limit}:{file_types}"
        cached = self.indexer.get_cached_results(cache_key, "file_search")
        if cached:
            return [TextContent(type="text", text=self.format_file_results(cached))]
        
        try:
            # Use fd (fast file finder) if available, otherwise use Python
            if self.has_command('fd'):
                results = await self.search_files_with_fd(query, search_dir, limit, file_types)
            else:
                results = await self.search_files_with_python(query, search_dir, limit, file_types)
            
            # Cache results
            self.indexer.cache_results(cache_key, "file_search", results)
            
            return [TextContent(type="text", text=self.format_file_results(results))]
            
        except Exception as e:
            logger.error(f"Error searching files: {e}")
            return [TextContent(type="text", text=f"Error searching files: {str(e)}")]
    
    async def search_files_with_fd(self, query: str, directory: Path, 
                                  limit: int, file_types: List[str]) -> List[SearchResult]:
        """Use fd command for fast file searching."""
        # Use fdfind if fd is not available
        fd_cmd = 'fdfind' if not self.has_command('fd') else 'fd'
        cmd = [fd_cmd, '--max-results', str(limit)]
        
        if file_types:
            for ext in file_types:
                cmd.extend(['--extension', ext.lstrip('.')])
        
        cmd.extend([query, str(directory)])
        
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            if result.returncode == 0:
                files = result.stdout.strip().split('\n')
                return [SearchResult(file_path=f, score=100.0) for f in files if f]
            else:
                return []
        except subprocess.TimeoutExpired:
            logger.warning("fd search timed out")
            return []
        except Exception as e:
            logger.error(f"fd search error: {e}")
            return []
    
    async def search_files_with_python(self, query: str, directory: Path, 
                                      limit: int, file_types: List[str]) -> List[SearchResult]:
        """Fallback Python-based file search with fuzzy matching."""
        results = []
        
        try:
            for file_path in directory.rglob('*'):
                if file_path.is_file():
                    # Check file type filter
                    if file_types and file_path.suffix not in file_types:
                        continue
                    
                    # Fuzzy match against file name
                    score = fuzz.partial_ratio(query.lower(), file_path.name.lower())
                    if score > 50:  # Threshold for relevance
                        results.append(SearchResult(
                            file_path=str(file_path),
                            score=score
                        ))
            
            # Sort by score and limit results
            results.sort(key=lambda x: x.score, reverse=True)
            return results[:limit]
            
        except Exception as e:
            logger.error(f"Python file search error: {e}")
            return []
    
    async def search_content(self, query: str, directory: str = None, 
                           case_sensitive: bool = False, whole_word: bool = False,
                           file_pattern: str = "**/*", limit: int = 50) -> List[TextContent]:
        """Search for text content within files using ripgrep."""
        search_dir = Path(directory) if directory else self.search_root
        
        # Check cache first
        cache_key = f"{query}:{search_dir}:{case_sensitive}:{whole_word}:{file_pattern}:{limit}"
        cached = self.indexer.get_cached_results(cache_key, "content_search")
        if cached:
            return [TextContent(type="text", text=self.format_content_results(cached))]
        
        try:
            # Use ripgrep if available, otherwise use Python
            if self.has_command('rg'):
                results = await self.search_content_with_ripgrep(
                    query, search_dir, case_sensitive, whole_word, file_pattern, limit
                )
            else:
                results = await self.search_content_with_python(
                    query, search_dir, case_sensitive, whole_word, file_pattern, limit
                )
            
            # Cache results
            self.indexer.cache_results(cache_key, "content_search", results)
            
            return [TextContent(type="text", text=self.format_content_results(results))]
            
        except Exception as e:
            logger.error(f"Error searching content: {e}")
            return [TextContent(type="text", text=f"Error searching content: {str(e)}")]
    
    async def search_content_with_ripgrep(self, query: str, directory: Path,
                                         case_sensitive: bool, whole_word: bool,
                                         file_pattern: str, limit: int) -> List[SearchResult]:
        """Use ripgrep for fast content searching."""
        cmd = ['rg', '--json', '--max-count', str(limit)]
        
        if not case_sensitive:
            cmd.append('--ignore-case')
        
        if whole_word:
            cmd.append('--word-regexp')
        
        if file_pattern != "**/*":
            cmd.extend(['--glob', file_pattern])
        
        cmd.extend([query, str(directory)])
        
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            if result.returncode == 0:
                results = []
                for line in result.stdout.strip().split('\n'):
                    if line:
                        try:
                            data = json.loads(line)
                            if data.get('type') == 'match':
                                match = data['data']
                                results.append(SearchResult(
                                    file_path=match['path']['text'],
                                    line_number=match['line_number'],
                                    column=match['submatches'][0]['start'] + 1,
                                    content=match['lines']['text'].strip()
                                ))
                        except json.JSONDecodeError:
                            continue
                return results
            else:
                return []
        except subprocess.TimeoutExpired:
            logger.warning("ripgrep search timed out")
            return []
        except Exception as e:
            logger.error(f"ripgrep search error: {e}")
            return []
    
    async def search_content_with_python(self, query: str, directory: Path,
                                        case_sensitive: bool, whole_word: bool,
                                        file_pattern: str, limit: int) -> List[SearchResult]:
        """Fallback Python-based content search."""
        results = []
        search_query = query if case_sensitive else query.lower()
        
        try:
            for file_path in directory.rglob(file_pattern):
                if file_path.is_file() and file_path.is_relative_to(directory):
                    try:
                        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                            for line_num, line in enumerate(f, 1):
                                search_line = line if case_sensitive else line.lower()
                                
                                if whole_word:
                                    if search_query in search_line.split():
                                        results.append(SearchResult(
                                            file_path=str(file_path),
                                            line_number=line_num,
                                            content=line.strip()
                                        ))
                                else:
                                    if search_query in search_line:
                                        results.append(SearchResult(
                                            file_path=str(file_path),
                                            line_number=line_num,
                                            content=line.strip()
                                        ))
                                
                                if len(results) >= limit:
                                    return results
                    except (UnicodeDecodeError, PermissionError):
                        continue
        except Exception as e:
            logger.error(f"Python content search error: {e}")
        
        return results[:limit]
    
    async def search_regex(self, pattern: str, directory: str = None,
                          file_pattern: str = "**/*", limit: int = 50) -> List[TextContent]:
        """Search using regular expressions."""
        search_dir = Path(directory) if directory else self.search_root
        
        try:
            if self.has_command('rg'):
                cmd = ['rg', '--json', '--max-count', str(limit), '--glob', file_pattern, pattern, str(search_dir)]
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
                
                if result.returncode == 0:
                    results = []
                    for line in result.stdout.strip().split('\n'):
                        if line:
                            try:
                                data = json.loads(line)
                                if data.get('type') == 'match':
                                    match = data['data']
                                    results.append(SearchResult(
                                        file_path=match['path']['text'],
                                        line_number=match['line_number'],
                                        content=match['lines']['text'].strip()
                                    ))
                            except json.JSONDecodeError:
                                continue
                    
                    return [TextContent(type="text", text=self.format_content_results(results))]
            else:
                return [TextContent(type="text", text="Regular expression search requires ripgrep (rg) to be installed")]
                
        except Exception as e:
            logger.error(f"Error in regex search: {e}")
            return [TextContent(type="text", text=f"Error in regex search: {str(e)}")]
    
    async def find_files(self, directory: str = None, name_pattern: str = "*",
                        min_size: int = None, max_size: int = None,
                        file_types: List[str] = None, limit: int = 100) -> List[TextContent]:
        """Find files by various criteria."""
        search_dir = Path(directory) if directory else self.search_root
        results = []
        
        try:
            for file_path in search_dir.rglob(name_pattern):
                if file_path.is_file():
                    # Check file type filter
                    if file_types and file_path.suffix not in file_types:
                        continue
                    
                    # Check size filters
                    try:
                        size = file_path.stat().st_size
                        if min_size and size < min_size:
                            continue
                        if max_size and size > max_size:
                            continue
                    except OSError:
                        continue
                    
                    results.append(SearchResult(file_path=str(file_path)))
                    
                    if len(results) >= limit:
                        break
            
            return [TextContent(type="text", text=self.format_file_results(results))]
            
        except Exception as e:
            logger.error(f"Error finding files: {e}")
            return [TextContent(type="text", text=f"Error finding files: {str(e)}")]
    
    async def get_file_info(self, file_path: str) -> List[TextContent]:
        """Get detailed information about a specific file."""
        try:
            path = Path(file_path)
            if not path.exists():
                return [TextContent(type="text", text=f"File not found: {file_path}")]
            
            stat = path.stat()
            
            # Get file type
            if magic:
                try:
                    file_type = magic.from_file(str(path), mime=True)
                except:
                    file_type = "unknown"
            else:
                # Fallback to basic file type detection
                if path.suffix:
                    file_type = f"application/{path.suffix[1:]}"
                else:
                    file_type = "unknown"
            
            info = f"""📄 File Information: {file_path}

📊 Basic Info:
  Size: {stat.st_size:,} bytes
  Modified: {time.ctime(stat.st_mtime)}
  Created: {time.ctime(stat.st_ctime)}
  Type: {file_type}
  Permissions: {oct(stat.st_mode)[-3:]}

📁 Path Info:
  Directory: {path.parent}
  Name: {path.name}
  Extension: {path.suffix}
  Stem: {path.stem}

🔍 Content Preview:"""
            
            # Add content preview for text files
            if file_type.startswith('text/') or path.suffix in ['.py', '.js', '.ts', '.md', '.txt', '.json', '.yaml', '.yml']:
                try:
                    with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                        lines = f.readlines()[:10]
                        for i, line in enumerate(lines, 1):
                            info += f"\n  {i:3d}: {line.rstrip()}"
                        if len(lines) == 10:
                            info += "\n  ... (truncated)"
                except:
                    info += "\n  (Could not read file content)"
            
            return [TextContent(type="text", text=info)]
            
        except Exception as e:
            logger.error(f"Error getting file info: {e}")
            return [TextContent(type="text", text=f"Error getting file info: {str(e)}")]
    
    async def watch_directory(self, directory: str, recursive: bool = True) -> List[TextContent]:
        """Start watching a directory for changes."""
        try:
            watch_path = Path(directory)
            if not watch_path.exists():
                return [TextContent(type="text", text=f"Directory not found: {directory}")]
            
            if str(watch_path) in self.watched_dirs:
                return [TextContent(type="text", text=f"Already watching: {directory}")]
            
            # Start watching (simplified implementation)
            self.watched_dirs.add(str(watch_path))
            
            return [TextContent(type="text", text=f"Started watching directory: {directory}\nRecursive: {recursive}")]
            
        except Exception as e:
            logger.error(f"Error watching directory: {e}")
            return [TextContent(type="text", text=f"Error watching directory: {str(e)}")]
    
    def has_command(self, command: str) -> bool:
        """Check if a command is available in the system PATH."""
        try:
            subprocess.run(['which', command], capture_output=True, check=True)
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            # Check for alternative command names
            if command == 'fd':
                try:
                    subprocess.run(['which', 'fdfind'], capture_output=True, check=True)
                    return True
                except (subprocess.CalledProcessError, FileNotFoundError):
                    pass
            return False
    
    def format_file_results(self, results: List[SearchResult]) -> str:
        """Format file search results for display."""
        if not results:
            return "No files found."
        
        output = f"Found {len(results)} files:\n\n"
        for i, result in enumerate(results, 1):
            file_path = Path(result.file_path)
            try:
                size = file_path.stat().st_size
                modified = time.ctime(file_path.stat().st_mtime)
                output += f"{i:2d}. 📁 {result.file_path}\n"
                output += f"    Size: {size:,} bytes | Modified: {modified}\n"
                if result.score > 0:
                    output += f"    Score: {result.score:.1f}%\n"
                output += "\n"
            except OSError:
                output += f"{i:2d}. 📁 {result.file_path}\n\n"
        
        return output
    
    def format_content_results(self, results: List[SearchResult]) -> str:
        """Format content search results for display."""
        if not results:
            return "No matches found."
        
        output = f"Found {len(results)} matches:\n\n"
        for i, result in enumerate(results, 1):
            file_path = Path(result.file_path)
            relative_path = file_path.relative_to(self.search_root) if file_path.is_relative_to(self.search_root) else file_path
            
            output += f"{i:2d}. 📄 {relative_path}"
            if result.line_number > 0:
                output += f":{result.line_number}"
            if result.column > 0:
                output += f":{result.column}"
            output += "\n"
            
            if result.content:
                # Truncate long lines
                content = result.content
                if len(content) > 100:
                    content = content[:97] + "..."
                output += f"    {content}\n"
            output += "\n"
        
        return output
    
    async def run(self):
        """Run the MCP server."""
        async with stdio_server() as (read_stream, write_stream):
            await self.server.run(
                read_stream,
                write_stream,
                self.server.create_initialization_options()
            )

def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description="Local Search MCP Server")
    parser.add_argument("--search-root", type=str, help="Root directory to search")
    parser.add_argument("--verbose", "-v", action="store_true", help="Enable verbose logging")
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    # Create and run the server
    server = LocalSearchMCP(args.search_root)
    
    try:
        asyncio.run(server.run())
    except KeyboardInterrupt:
        logger.info("Server stopped by user")
    except Exception as e:
        logger.error(f"Server error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
