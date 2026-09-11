# Self-Healing Web Application Platform
# Installation and Operations Guide

This guide explains how to clone, install, verify, test, troubleshoot, and
demonstrate the complete Self-Healing Web Application Platform.

The project is designed for Linux hosts using Docker, Docker Compose, and
systemd.

---

# 1. Architecture

The platform implements the following self-healing flow:

Application
    |
    v
Prometheus
    |
    | ApplicationDown alert
    v
Alertmanager
    |
    | HTTP webhook
    v
Recovery Service
    |
    v
Recovery Script
    |
    v
Docker
    |
    v
Application recovered

The recovery service is managed by systemd.

---

# 2. Technology Stack

The project uses:

- Python
- Flask
- Gunicorn
- Docker
- Docker Compose
- Docker Health Checks
- Docker Restart Policies
- Prometheus
- Node Exporter
- Grafana
- Alertmanager
- Webhooks
- systemd
- Bash
- Git
- GitHub Actions
- Infrastructure readiness checks
- Failure injection
- Automated recovery
- Observability
- SRE principles

---

# 3. System Requirements

Recommended minimum:

- Ubuntu 22.04 or Ubuntu 24.04
- 4 vCPU
- 8 GB RAM
- 30 GB free disk space
- systemd
- Internet connectivity
- sudo access
- User with Docker access

The infrastructure bootstrap script checks CPU, RAM, disk, Docker,
required tools, networking utilities, and project ports.

---

# 4. Clone the Repository

Clone the repository:

    git clone https://github.com/Avijit-devops/self-healing-web-platform.git

Enter the project:

    cd self-healing-web-platform

Verify:

    pwd
    ls -la

---

# 5. Configure Environment Variables

Create the local environment file:

    cp .env.example .env

Edit it:

    nano .env

Set a Grafana administrator password:

    GF_SECURITY_ADMIN_PASSWORD=change-me

Use a strong password for any real deployment.

IMPORTANT:

Do not commit `.env`.

The repository ignores `.env` files while allowing `.env.example`
to be committed.

---

# 6. Infrastructure Readiness Check

The infrastructure readiness script is:

    scripts/bootstrap-infra.sh

It checks:

- Operating system
- Architecture
- CPU
- RAM
- Disk
- Virtualization
- Docker
- Docker Compose
- Git
- Python
- Ansible
- Terraform
- Networking utilities
- Existing Docker workloads
- Docker networks
- Required ports

Run it manually:

    ./scripts/bootstrap-infra.sh

A bootstrap report is generated under:

    logs/bootstrap-report.txt

The script is designed to avoid removing existing Docker containers,
images, volumes, and networks.

---

# 7. One-Command Platform Setup

The recommended installation method is:

    ./setup.sh

The setup script:

1. Detects the repository directory.
2. Detects the current Linux user.
3. Runs the infrastructure readiness/bootstrap script.
4. Creates a Python virtual environment for the recovery service.
5. Installs Flask and Gunicorn for the recovery service.
6. Builds the Docker application.
7. Starts the Docker Compose platform.
8. Creates the systemd recovery service.
9. Reloads systemd.
10. Enables the recovery service.
11. Starts the recovery service.
12. Displays the final service status.

The setup script does not depend on a hard-coded `/home/user/...` path.

---

# 8. Verify Docker Services

Check all services:

    docker compose ps

Expected services:

- self-healing-app
- prometheus
- alertmanager
- node-exporter
- grafana

The application should report:

    Up ... (healthy)

The monitoring services should also be running and healthy.

---

# 9. Verify the Application

Test the root endpoint:

    curl http://localhost:8080/

Expected response:

    {
      "message": "Self-Healing Web Application Platform API is operational",
      "status": "running"
    }

Test health:

    curl http://localhost:8080/health

Expected:

    {"status":"healthy"}

Test metrics:

    curl http://localhost:8080/metrics

Prometheus metrics should be returned.

---

# 10. Verify the Recovery Service

Check systemd:

    sudo systemctl is-active self-healing-recovery

Expected:

    active

Check the recovery API:

    curl http://localhost:5001/health

Expected:

    {"status":"healthy"}

Check detailed service status:

    sudo systemctl status self-healing-recovery

---

# 11. Verify Prometheus

Open:

    http://<SERVER-IP>:9090

Check:

    Status -> Targets

The following targets should be UP:

- flask-app
- node-exporter
- prometheus

Test an application metric:

    curl -s http://localhost:9090/api/v1/query?query=up%7Bjob%3D%22flask-app%22%7D

The application target should return:

    "value": [ ..., "1" ]

---

# 12. Verify Grafana

Open:

    http://<SERVER-IP>:3000

Use:

    Username:
    admin

    Password:
    Value configured in .env

The Prometheus datasource and project dashboard are provisioned
automatically.

---

# 13. Verify Alertmanager

Open:

    http://<SERVER-IP>:9093

Check that Alertmanager is healthy.

The configured receiver is:

    recovery-webhook

The webhook points to the host recovery service.

---

# 14. Test Application Failure

This is the main self-healing demonstration.

First verify the application:

    curl http://localhost:8080/health

Then intentionally stop the application:

    docker stop self-healing-app

Confirm failure:

    docker compose ps -a

The application should show:

    Exited

Do NOT manually start the application.

The monitoring system should recover it automatically.

---

# 15. Observe the Prometheus Alert

The Prometheus rule is:

    ApplicationDown

The alert expression checks:

    up{job="flask-app"} == 0

The alert fires after the configured duration.

You can inspect Prometheus alerts:

    curl -s http://localhost:9090/api/v1/alerts | jq

Look for:

    ApplicationDown

with:

    "state": "firing"

---

# 16. Observe Alertmanager

Check Alertmanager:

    curl -s http://localhost:9093/api/v2/alerts | jq

The ApplicationDown alert should be delivered to Alertmanager.

Alertmanager then sends the webhook to:

    /recover

---

# 17. Observe the Recovery Service

Watch the systemd logs:

    sudo journalctl -u self-healing-recovery -f

A successful recovery should contain messages similar to:

    Received Alertmanager webhook

    Alert: ApplicationDown, Status: firing

    self-healing-app is down. Starting container...

    self-healing-app

    self-healing-app recovery command completed

The HTTP request should return:

    200

and the User-Agent should identify Alertmanager.

---

# 18. Verify Automatic Recovery

After the recovery webhook executes:

    docker compose ps

The application should again be:

    Up ... (healthy)

Verify the health endpoint:

    curl http://localhost:8080/health

Expected:

    {"status":"healthy"}

This proves the complete recovery chain:

    Application failure
        ->
    Prometheus detection
        ->
    ApplicationDown alert
        ->
    Alertmanager
        ->
    HTTP webhook
        ->
    Recovery service
        ->
    Bash recovery script
        ->
    docker start
        ->
    Healthy application

---

# 19. Test the Recovery Service Independently

The recovery script can also be tested directly.

Stop the application:

    docker stop self-healing-app

Run:

    ./scripts/recover-app.sh

Verify:

    docker inspect --format='Status={{.State.Status}} Health={{.State.Health.Status}}' self-healing-app

Then:

    curl http://localhost:8080/health

Expected:

    Status=running Health=healthy

and:

    {"status":"healthy"}

---

# 20. Test systemd Self-Healing

The recovery service itself is managed by systemd.

Check the process:

    systemctl status self-healing-recovery

Get the main PID:

    systemctl show -p MainPID --value self-healing-recovery

For a controlled lab test, terminate the recovery service process:

    sudo kill -9 <MAIN_PID>

systemd should automatically restart it.

Verify:

    sudo systemctl is-active self-healing-recovery

Expected:

    active

Then:

    curl http://localhost:5001/health

Expected:

    {"status":"healthy"}

---

# 21. Failure Injection Endpoint

The application also contains:

    /force-error

Test it:

    curl -i http://localhost:8080/force-error

Expected:

    HTTP/1.1 500 INTERNAL SERVER ERROR

This endpoint intentionally generates an application error for
observability and testing.

IMPORTANT:

This endpoint tests application error handling.

It does NOT simulate the complete container-down recovery path.

For the complete self-healing demonstration, use:

    docker stop self-healing-app

---

# 22. Useful Logs

Application logs:

    docker logs self-healing-app

Prometheus logs:

    docker logs prometheus

Alertmanager logs:

    docker logs alertmanager

Grafana logs:

    docker logs grafana

Recovery service logs:

    sudo journalctl -u self-healing-recovery

Follow recovery logs:

    sudo journalctl -u self-healing-recovery -f

Bootstrap report:

    cat logs/bootstrap-report.txt

---

# 23. Useful Health Checks

Application:

    curl http://localhost:8080/health

Recovery service:

    curl http://localhost:5001/health

Grafana:

    curl http://localhost:3000/api/health

Docker services:

    docker compose ps

Systemd:

    sudo systemctl is-active self-healing-recovery

---

# 24. Troubleshooting

## Application is not running

Check:

    docker compose ps -a

Then:

    docker logs self-healing-app

Check the health state:

    docker inspect --format='{{.State.Health.Status}}' self-healing-app

---

## Recovery service is not running

Check:

    sudo systemctl status self-healing-recovery

Check logs:

    sudo journalctl -u self-healing-recovery -n 100 --no-pager

---

## Alertmanager cannot reach recovery service

Check:

    curl http://localhost:5001/health

Then:

    docker exec alertmanager \
      wget -qO- http://host.docker.internal:5001/health

The Docker Compose configuration uses the host gateway mapping required
for Linux:

    host.docker.internal:host-gateway

---

## Prometheus target is DOWN

Check:

    curl http://localhost:8080/metrics

Then:

    docker logs prometheus

Also check:

    docker compose ps

---

## Port conflict

Required project ports:

- 8080 - application
- 3000 - Grafana
- 9090 - Prometheus
- 9093 - Alertmanager
- 9100 - Node Exporter
- 5001 - recovery webhook

Check a port:

    sudo ss -lntup | grep :8080

---

# 25. Stop the Platform

To stop the Docker platform:

    docker compose down

This removes the project containers but keeps named volumes.

Start again:

    docker compose up -d --build

The recovery systemd service can remain enabled independently.

---

# 26. Complete Demonstration Checklist

For an interview or portfolio demonstration:

[ ] Clone repository

[ ] Configure .env

[ ] Run infrastructure readiness check

[ ] Run ./setup.sh

[ ] Verify Docker services

[ ] Verify application /health

[ ] Verify Prometheus targets

[ ] Verify Grafana

[ ] Verify Alertmanager

[ ] Verify recovery service

[ ] Stop self-healing-app

[ ] Observe ApplicationDown alert

[ ] Observe Alertmanager webhook

[ ] Observe recovery service logs

[ ] Verify Docker automatically starts application

[ ] Verify application health

[ ] Show Grafana metrics

[ ] Show GitHub Actions CI

---

# 27. SRE Recovery Model

The project demonstrates:

    DETECT
       |
       v
    ALERT
       |
       v
    RECOVER
       |
       v
    OBSERVE
       |
       v
    VALIDATE

The objective is to reduce manual intervention during common
application failures while maintaining observability and clear
recovery actions.

---

# 28. Security Notes

The recovery webhook is a privileged operational endpoint because it
can start the application container.

For a production deployment:

- Do not expose port 5001 publicly.
- Restrict access using firewall/network policy.
- Authenticate webhook requests.
- Use TLS where appropriate.
- Run the recovery service with the minimum required privileges.
- Audit recovery actions.
- Avoid exposing administrative endpoints to untrusted networks.

This project is intended primarily as a DevOps/SRE learning and
portfolio platform.
