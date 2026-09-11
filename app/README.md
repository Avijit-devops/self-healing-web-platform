# Self-Healing Platform - Web Application

A minimal, production-ready Python Flask application serving as the application layer for the **Self-Healing Web Application Platform**. 

This application exposes core endpoints for health checking and Prometheus metrics collection, logging all events directly to `stdout`/`stderr` for easy container log harvesting.

---

## 🚀 Features

- **Flask Microservice**: Simple, lightweight Python web application without external database dependencies.
- **Prometheus Metrics**: Built-in metrics tracking total HTTP requests, request latency histogram, and HTTP error counts using `prometheus_client`.
- **Structured Log Output**: Standard Python logging piped to standard output (`stdout`), tailored for Docker log drivers and observability agents.
- **Graceful Error Handling**: Global exception handling that outputs structured JSON responses with HTTP 500 status codes for unhandled exceptions.
- **Configurable Port**: Configurable execution port via environment variable `APP_PORT` (defaults to `8080`).

---

## 📡 Available Endpoints

| Endpoint | Method | Description |
| :--- | :--- | :--- |
| `/` | `GET` | Returns JSON status showing the application is operational. |
| `/health` | `GET` | Returns HTTP 200 JSON (`{"status": "healthy"}`) for health check / liveness probes. |
| `/metrics` | `GET` | Exposes Prometheus-compatible application performance metrics. |
| `/force-error` | `GET` | Triggers a simulated HTTP 500 internal server error for testing fault handling. |

---

## 🛠️ Installation

### Prerequisites

- Python 3.10+
- `pip` (Python package manager)

### Install Dependencies

From the `app/` directory (or root directory), install the required dependencies:

```bash
pip install -r app/requirements.txt
```

*(Optional)* It is recommended to use a virtual environment:

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r app/requirements.txt
```

---

## 🏃 Running Locally

To launch the application using the default port (`8080`):

```bash
PYTHONPATH=app python3 app/app.py
```

### Customizing the Port

Specify the `APP_PORT` environment variable to run on a different port (e.g., `9090`):

```bash
APP_PORT=9090 PYTHONPATH=app python3 app/app.py
```

### Quick Verification

Test the endpoints using `curl`:

```bash
# Check status
curl http://localhost:8080/

# Check health
curl http://localhost:8080/health

# View Prometheus metrics
curl http://localhost:8080/metrics

# Test error handling
curl http://localhost:8080/force-error
```

---

## 🧪 Running Tests

Unit tests are written using `pytest`.

To run the test suite:

```bash
PYTHONPATH=app pytest app/test_app.py
```

Or run `pytest` directly inside the `app/` directory:

```bash
cd app
pytest
```

---

## 🐳 Docker Containerization

### Build & Run with Docker Compose (Recommended)

```bash
# Build and start container in detached mode
docker compose up -d --build

# Check container status and healthcheck state
docker compose ps

# View real-time container logs
docker compose logs -f self-healing-app

# Stop and remove container
docker compose down
```

### Build & Run with Docker CLI

```bash
# Build the image
docker build -t self-healing-app:latest .

# Run container as daemon
docker run -d --name self-healing-app -p 8080:8080 -e APP_PORT=8080 self-healing-app:latest

# Inspect container health check status
docker inspect --format='{{json .State.Health.Status}}' self-healing-app

# View container stdout/stderr logs
docker logs -f self-healing-app

# Stop container
docker stop self-healing-app && docker rm self-healing-app
```

