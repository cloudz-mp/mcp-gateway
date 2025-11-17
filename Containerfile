FROM python:3.12-slim
LABEL maintainer="Mihai Criveti" \
      name="mcp/mcpgateway" \
      version="0.8.3" \
      description="MCP Gateway: An enterprise-ready Model Context Protocol Gateway"

# Install additional build dependencies
# hadolint ignore=DL3041
RUN apt-get update && \
    apt-get install -y gcc git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy project files into container
COPY . /app

# Create virtual environment, upgrade pip and install dependencies using uv for speed
# Including observability packages for OpenTelemetry support
RUN python3 -m venv /app/.venv && \
    /app/.venv/bin/python3 -m pip install --upgrade pip setuptools pdm uv && \
    /app/.venv/bin/python3 -m uv pip install ".[redis,postgres,mysql,alembic,observability]"

# update the user permissions
RUN chown -R 1001:0 /app && \
    chmod -R g=u /app

# Expose the application port
EXPOSE 4444

# Set the runtime user
USER 1001

# Ensure virtual environment binaries are in PATH
ENV PATH="/app/.venv/bin:$PATH"

# Start the application using run-gunicorn.sh
CMD ["./run-gunicorn.sh"]
