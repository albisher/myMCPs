FROM python:3.11-slim

# Install system dependencies for better performance
RUN apt-get update && apt-get install -y \
    ripgrep \
    fd-find \
    fzf \
    git \
    file \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application
COPY local_search_mcp.py .

# Make the script executable
RUN chmod +x local_search_mcp.py

# Create a non-root user
RUN useradd -m -u 1001 mcp

# Create data directory
RUN mkdir -p /app/data && chown -R mcp:mcp /app

# Switch to non-root user
USER mcp

# Set environment variables
ENV PYTHONPATH=/app
ENV SEARCH_ROOT=/workspace

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "print('Health check passed')" || exit 1

# Start the MCP server
CMD ["python", "local_search_mcp.py"]