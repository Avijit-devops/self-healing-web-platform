import os
import sys
import time
import logging
from flask import Flask, jsonify, request, Response
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from werkzeug.exceptions import HTTPException

# Configure logging to output to stdout for container/log collector aggregation
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s - %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger("self-healing-app")

app = Flask(__name__)

# Prometheus Application Metrics
HTTP_REQUESTS_TOTAL = Counter(
    "http_requests_total",
    "Total HTTP request count",
    ["method", "endpoint", "status"]
)

HTTP_REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["method", "endpoint"]
)

HTTP_ERRORS_TOTAL = Counter(
    "http_errors_total",
    "Total HTTP error count",
    ["endpoint", "status"]
)


@app.before_request
def start_timer():
    """Record request start time for latency calculations."""
    request.start_time = time.time()


@app.after_request
def log_and_record_metrics(response):
    """Record request duration, counts, and error metrics, then log the request."""
    endpoint = request.endpoint or request.path

    if hasattr(request, "start_time"):
        latency = time.time() - request.start_time
        HTTP_REQUEST_LATENCY.labels(method=request.method, endpoint=endpoint).observe(latency)

    status = str(response.status_code)
    HTTP_REQUESTS_TOTAL.labels(method=request.method, endpoint=endpoint, status=status).inc()

    if response.status_code >= 400:
        HTTP_ERRORS_TOTAL.labels(endpoint=endpoint, status=status).inc()

    logger.info("%s %s -> HTTP %s", request.method, request.path, response.status_code)
    return response


@app.route("/", methods=["GET"])
def index():
    """Root endpoint showing application status."""
    return jsonify({
        "status": "running",
        "message": "Self-Healing Web Application Platform API is operational"
    }), 200


@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint for liveness/readiness probes."""
    return jsonify({
        "status": "healthy"
    }), 200


@app.route("/metrics", methods=["GET"])
def metrics():
    """Exposes Prometheus application metrics."""
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)


@app.route("/force-error", methods=["GET"])
def force_error():
    """Endpoint to simulate an unexpected server error for testing and self-healing validation."""
    raise RuntimeError("Simulated unexpected internal server error")


@app.errorhandler(Exception)
def handle_exception(e):
    """Global exception handler to gracefully return HTTP 500 for unhandled errors."""
    if isinstance(e, HTTPException):
        logger.warning("HTTP Exception: %s", e)
        return jsonify({
            "error": e.name,
            "message": e.description
        }), e.code

    logger.error("Unhandled exception: %s", e, exc_info=True)
    return jsonify({
        "error": "Internal Server Error",
        "message": "An unexpected error occurred on the server."
    }), 500


if __name__ == "__main__":
    port_str = os.getenv("APP_PORT", "8080")
    try:
        port = int(port_str)
    except ValueError:
        logger.warning("Invalid APP_PORT '%s', falling back to default 8080", port_str)
        port = 8080

    logger.info("Starting Self-Healing Platform App on port %d...", port)
    app.run(host="0.0.0.0", port=port)
