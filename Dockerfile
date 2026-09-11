# Use official lightweight Python 3.10 slim image
FROM python:3.10-slim

# Set working directory inside container
WORKDIR /app

# Set environment variables for Python & application
ENV APP_PORT=8080 \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Install curl for container health check and cleanup apt lists to keep image minimal
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# Copy requirements file first to leverage Docker layer caching
COPY app/requirements.txt /app/requirements.txt

# Install dependencies without package caching
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source code
COPY app/ /app/

# Create a non-root system user and set directory ownership
RUN groupadd -r appuser && \
    useradd -r -g appuser -d /app appuser && \
    chown -R appuser:appuser /app

# Switch to non-root user for security
USER appuser

# Expose target application port
EXPOSE 8080

# Container health check configuration targeting /health endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Start application using production WSGI server Gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--timeout", "30", "--graceful-timeout", "30", "--access-logfile", "-", "--error-logfile", "-", "app:app"]

