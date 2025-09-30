FROM python:3.12-slim
LABEL maintainer="Mihai Criveti" \
      name="mcp/mcpgateway" \
      version="0.8.0" \
      description="MCP Gateway: An enterprise-ready Model Context Protocol Gateway"

# Install additional build dependencies
# hadolint ignore=DL3041
RUN apt-get update && \
    apt-get install -y gcc git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ----------------------------------------------------------------------------
# s390x architecture does not support BoringSSL when building wheel grpcio.
# Force Python whl to use OpenSSL.
# ----------------------------------------------------------------------------
RUN if [ "$TARGETPLATFORM" = "linux/s390x" ]; then \
        echo "Building for s390x."; \
        echo "export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL='True'" > /etc/profile.d/use-openssl.sh; \
    else \
        echo "export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL='False'" > /etc/profile.d/use-openssl.sh; \
    fi
RUN chmod 644 /etc/profile.d/use-openssl.sh

# Copy project files into container
COPY . /app

# Copy Rust plugin wheels from builder (if any exist)
COPY --from=rust-builder /build/plugins_rust/target/wheels/ /tmp/rust-wheels/

# Create virtual environment, upgrade pip and install dependencies using uv for speed
# Including observability packages for OpenTelemetry support and Rust plugins (if built)
ARG ENABLE_RUST=false
RUN python3 -m venv /app/.venv && \
    . /etc/profile.d/use-openssl.sh && \
    /app/.venv/bin/python3 -m pip install --upgrade pip setuptools pdm uv && \
    /app/.venv/bin/python3 -m uv pip install ".[redis,postgres,mysql,alembic,observability]" && \
    if [ "$ENABLE_RUST" = "true" ] && ls /tmp/rust-wheels/*.whl 1> /dev/null 2>&1; then \
        echo "🦀 Installing Rust plugins..."; \
        /app/.venv/bin/python3 -m pip install /tmp/rust-wheels/mcpgateway_rust-*-manylinux*.whl && \
        /app/.venv/bin/python3 -c "from plugins_rust import PIIDetectorRust; print('✓ Rust PII filter installed successfully')"; \
    else \
        echo "⏭️  Rust plugins not available - using Python implementations"; \
    fi && \
    rm -rf /tmp/rust-wheels

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
