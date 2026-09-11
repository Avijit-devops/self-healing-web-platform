# Self-Healing Web Application Platform

A production-style DevOps/SRE project demonstrating automated application recovery, container health checks, infrastructure monitoring, metrics collection, Grafana visualization, and CI automation.

## 🚀 Project Overview

This project runs a Flask web application inside Docker and automatically recovers from unexpected application process failures.

The platform includes:

* Flask web application
* Gunicorn production WSGI server
* Docker containerization
* Docker health checks
* Automatic container restart
* Prometheus monitoring
* Node Exporter host monitoring
* Grafana dashboard
* GitHub Actions CI pipeline

The self-healing behavior was tested by deliberately terminating the Gunicorn process and verifying that Docker automatically restarted the application.

---

## 🎯 Problem Statement

A web application process can fail because of:

* Application crashes
* Unexpected runtime errors
* Resource exhaustion
* Process failures
* Configuration problems
* Infrastructure issues

Without automated recovery, an engineer may need to manually detect the problem and restart the service.

This project demonstrates automated recovery:

```text
Application Process Failure
          |
          v
Docker Container Stops
          |
          v
Docker Restart Policy
          |
          v
Container Automatically Restarts
          |
          v
Health Check
          |
          v
Application Healthy
          |
          v
Service Available Again
```

---

## 🏗️ Architecture

```text
                         USER
                          |
                          v
                  +---------------+
                  | Flask Web App |
                  +-------+-------+
                          |
                       Gunicorn
                          |
                          v
                +-------------------+
                | Docker Container  |
                | self-healing-app  |
                +---------+---------+
                          |
                    Health Check
                          |
                          v
                  Docker Restart
                          |
                          v
                    Auto Recovery


              +----------------------+
              |      Prometheus      |
              |    Metrics Server    |
              +----------+-----------+
                         |
              +----------+-----------+
              |                      |
              v                      v
       Flask /metrics          Node Exporter
              |                      |
              +----------+-----------+
                         |
                         v
                    +---------+
                    | Grafana |
                    +---------+


Developer
    |
    v
Git Push
    |
    v
GitHub Actions
    |
    +----> Python Tests
    |
    +----> Docker Build
```

---

## 🔧 Technology Stack

| Technology     | Purpose                       |
| -------------- | ----------------------------- |
| Ubuntu Linux   | Host operating system         |
| Python         | Application runtime           |
| Flask          | Web application framework     |
| Gunicorn       | Production WSGI server        |
| Docker         | Containerization              |
| Docker Compose | Multi-container orchestration |
| Prometheus     | Metrics collection            |
| Node Exporter  | Host infrastructure metrics   |
| Grafana        | Monitoring dashboard          |
| Git            | Version control               |
| GitHub         | Source code repository        |
| GitHub Actions | CI automation                 |
| PromQL         | Metrics queries               |
| cURL           | API and health testing        |
| jq             | JSON processing               |

---

## 📁 Repository Structure

```text
self-healing-web-platform/
│
├── .github/
│   └── workflows/
│       └── ci.yml
│
├── app/
│   ├── app.py
│   ├── requirements.txt
│   ├── test_app.py
│   └── README.md
│
├── monitoring/
│   ├── prometheus/
│   │   └── prometheus.yml
│   │
│   └── grafana/
│       ├── dashboards/
│       │   └── self-healing-platform.json
│       │
│       └── provisioning/
│           ├── dashboards/
│           └── datasources/
│
├── Dockerfile
├── docker-compose.yml
├── .dockerignore
├── .gitignore
└── README.md
```

---

# 🐍 Application

The application is built using Flask and served using Gunicorn.

### Endpoints

| Endpoint       | Purpose                                |
| -------------- | -------------------------------------- |
| `/`            | Application status                     |
| `/health`      | Health check                           |
| `/metrics`     | Prometheus metrics                     |
| `/force-error` | Controlled HTTP 500 failure simulation |

### Test Application

```bash
curl http://localhost:8080/
```

### Test Health

```bash
curl http://localhost:8080/health
```

Expected response:

```json
{
  "status": "healthy"
}
```

### Test Metrics

```bash
curl http://localhost:8080/metrics
```

---

# ❤️ Self-Healing Mechanism

The application container uses the Docker restart policy:

```yaml
restart: unless-stopped
```

The application also uses a Docker health check.

Gunicorn runs multiple workers:

```text
             Gunicorn
                 |
        +--------+--------+
        |                 |
        v                 v
    Worker 1          Worker 2
```

If the Gunicorn master process unexpectedly terminates, Docker detects the container process failure and automatically restarts the container.

### Recovery Flow

```text
Gunicorn Process Failure
          |
          v
Container Process Terminates
          |
          v
Docker Detects Failure
          |
          v
Container Automatically Restarts
          |
          v
New Container PID
          |
          v
Docker Health Check
          |
          v
Healthy
          |
          v
HTTP 200
```

---

# 🧪 Failure Simulation

The self-healing mechanism was tested using an actual process failure.

First, identify the Gunicorn process:

```bash
docker top self-healing-app
```

Check the container state:

```bash
docker inspect \
  --format='PID={{.State.Pid}} Status={{.State.Status}} RestartCount={{.RestartCount}}' \
  self-healing-app
```

Deliberately terminate the Gunicorn process:

```bash
sudo kill -9 <gunicorn-pid>
```

Docker automatically restarts the container.

Verify recovery:

```bash
docker inspect \
  --format='PID={{.State.Pid}} Status={{.State.Status}} Health={{.State.Health.Status}} RestartCount={{.State.RestartCount}}' \
  self-healing-app
```

The actual test demonstrated:

```text
RestartCount: 0
       |
       v
Gunicorn Process Failure
       |
       v
Docker Container Restart
       |
       v
RestartCount: 1
       |
       v
Health: healthy
       |
       v
HTTP 200
```

Application availability was verified:

```bash
curl -i http://localhost:8080/health
```

Expected:

```text
HTTP/1.1 200 OK
```

This validates an actual failure-and-recovery scenario rather than simply configuring a restart policy.

---

# 📊 Monitoring

## Prometheus

Prometheus collects metrics from the application and host infrastructure.

### Flask Application

```text
self-healing-app:8080/metrics
```

### Node Exporter

```text
node-exporter:9100/metrics
```

### Prometheus

```text
localhost:9090
```

Check Prometheus targets:

```bash
curl -s http://localhost:9090/api/v1/targets | jq
```

Expected targets:

```text
flask-app
node-exporter
prometheus
```

All targets should report:

```text
health: up
```

---

# 📈 Prometheus Metrics

The Flask application exposes metrics including:

```text
http_requests_total
http_request_duration_seconds
http_errors_total
```

It also exposes standard Python process metrics.

### Total HTTP Requests

```promql
sum(http_requests_total)
```

### CPU Utilization

```promql
100 - (
  avg by(instance)(
    rate(node_cpu_seconds_total{mode="idle"}[5m])
  ) * 100
)
```

### Memory Utilization

```promql
100 * (
  1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes
)
```

---

# 📊 Grafana

Grafana provides visualization for application and infrastructure metrics.

Grafana:

```text
http://localhost:3000
```

The dashboard is automatically provisioned from:

```text
monitoring/grafana/dashboards/
```

The Prometheus datasource is provisioned from:

```text
monitoring/grafana/provisioning/datasources/
```

This allows the monitoring configuration to be maintained as code.

---

# 🐳 Running the Platform

Clone the repository:

```bash
git clone https://github.com/Avijit-devops/self-healing-web-platform.git
```

Enter the project:

```bash
cd self-healing-web-platform
```

Set the Grafana password:

```bash
export GF_SECURITY_ADMIN_PASSWORD='your-secure-password'
```

Start the platform:

```bash
docker compose up -d --build
```

Check services:

```bash
docker compose ps
```

Expected services:

```text
grafana
node-exporter
prometheus
self-healing-app
```

---

# 🔍 Verify the Platform

### Application

```bash
curl http://localhost:8080/
```

### Health

```bash
curl http://localhost:8080/health
```

### Metrics

```bash
curl http://localhost:8080/metrics
```

### Prometheus

```text
http://localhost:9090
```

### Grafana

```text
http://localhost:3000
```

---

# 🧪 Testing

Install Python dependencies:

```bash
pip install -r app/requirements.txt
```

Run unit tests:

```bash
pytest -q app/test_app.py
```

Test the application:

```bash
curl http://localhost:8080/
```

Test the health endpoint:

```bash
curl http://localhost:8080/health
```

Test Prometheus metrics:

```bash
curl http://localhost:8080/metrics
```

Simulate an application error:

```bash
curl -i http://localhost:8080/force-error
```

The `/force-error` endpoint should return:

```text
HTTP 500
```

---

# 🔄 GitHub Actions CI

The project includes a GitHub Actions CI pipeline.

The pipeline runs automatically for:

* Pushes to `main`
* Pull requests targeting `main`

Pipeline:

```text
Developer Push
      |
      v
GitHub Actions
      |
      v
Checkout Code
      |
      v
Setup Python 3.10
      |
      v
Install Dependencies
      |
      v
Run Python Tests
      |
      v
Tests PASS
      |
      v
Build Docker Image
      |
      v
CI PASS
```

Workflow:

```text
.github/workflows/ci.yml
```

The Docker image is currently built as a validation step and is not pushed to a container registry.

---

# 🛠️ Troubleshooting

### Check Application Logs

```bash
docker logs self-healing-app
```

### Check Prometheus Logs

```bash
docker logs prometheus
```

### Check Grafana Logs

```bash
docker logs grafana
```

### Check Container Health

```bash
docker inspect \
  --format='{{.State.Health.Status}}' \
  self-healing-app
```

### Check Restart Count

```bash
docker inspect \
  --format='{{.RestartCount}}' \
  self-healing-app
```

### Check All Services

```bash
docker compose ps
```

---

# 📌 Project Outcomes

This project demonstrates practical DevOps/SRE skills in:

* Linux administration
* Git and GitHub
* Docker
* Docker Compose
* Python
* Flask
* Gunicorn
* Container health checks
* Automated recovery
* Prometheus
* Node Exporter
* Grafana
* PromQL
* Observability
* Failure injection
* Troubleshooting
* CI automation
* Configuration as Code

The most important validation was an actual process failure followed by automatic recovery.

```text
Detect
  |
Recover
  |
Observe
  |
Validate
```

---

# 🚧 Future Improvements

Planned improvements include:

* Docker image publishing
* Container registry integration
* Automated deployment
* Terraform infrastructure provisioning
* Ansible configuration management
* Prometheus Alertmanager
* Centralized logging
* Security scanning
* Container vulnerability scanning
* Kubernetes deployment
* Kubernetes self-healing
* Rolling deployments
* Service Level Objectives
* Error budget

---

## ⭐ Engineering Principle

This project follows:

```text
DETECT → RECOVER → OBSERVE → VALIDATE
```

The goal is not simply to restart a failed service, but to demonstrate automated recovery together with monitoring, testing, and repeatable failure validation.
