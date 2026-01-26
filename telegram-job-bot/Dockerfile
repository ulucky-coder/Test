# Build stage
FROM python:3.11-slim as builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip wheel --no-cache-dir --no-deps --wheel-dir /app/wheels -r requirements.txt

# Production stage
FROM python:3.11-slim

WORKDIR /app

# Create non-root user
RUN groupadd -r botuser && useradd -r -g botuser botuser

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libffi8 \
    && rm -rf /var/lib/apt/lists/*

# Copy wheels and install
COPY --from=builder /app/wheels /wheels
RUN pip install --no-cache /wheels/*

# Copy application code
COPY src/ ./src/
COPY scripts/ ./scripts/

# Create directories
RUN mkdir -p /app/sessions /app/logs && \
    chown -R botuser:botuser /app

# Switch to non-root user
USER botuser

# Environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    SESSION_PATH=/app/sessions

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')" || exit 1

# Expose webhook port
EXPOSE 8080

# Default command
CMD ["python", "-m", "src.main"]
