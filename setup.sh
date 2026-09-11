#!/bin/bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_USER="$(whoami)"
VENV_DIR="$PROJECT_DIR/recovery/.venv"
GUNICORN="$VENV_DIR/bin/gunicorn"
INFRA_SCRIPT="$PROJECT_DIR/scripts/bootstrap-infra.sh"
if [ ! -f "$INFRA_SCRIPT" ]; then
    echo "ERROR: Infrastructure bootstrap script not found:"
    echo "$INFRA_SCRIPT"
    exit 1
fi

if [ ! -x "$INFRA_SCRIPT" ]; then
    chmod +x "$INFRA_SCRIPT"
fi

echo
echo "======================================"
echo " Infrastructure Readiness"
echo "======================================"

"$INFRA_SCRIPT"
echo "======================================"
echo " Self-Healing Platform Setup"
echo "======================================"
echo "Project directory: $PROJECT_DIR"
echo "User:              $CURRENT_USER"

# Check Docker
if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: Docker is not installed."
    exit 1
fi

# Check Docker Compose
if ! docker compose version >/dev/null 2>&1; then
    echo "ERROR: Docker Compose plugin is not installed."
    exit 1
fi

# Check Python
if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: Python 3 is not installed."
    exit 1
fi

# Check Docker access
if ! docker ps >/dev/null 2>&1; then
    echo "ERROR: Current user cannot access Docker."
    echo "Add the user to the docker group and log in again."
    exit 1
fi

echo
echo "[1/5] Creating recovery virtual environment..."

if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
fi

echo
echo "[2/5] Installing recovery service dependencies..."

"$VENV_DIR/bin/python" -m pip install --upgrade pip
"$VENV_DIR/bin/pip" install -r "$PROJECT_DIR/recovery/requirements.txt"

echo
echo "[3/5] Starting Docker services..."

docker compose up -d --build

echo
echo "[4/5] Creating systemd recovery service..."

sudo tee /etc/systemd/system/self-healing-recovery.service > /dev/null <<EOF
[Unit]
Description=Self-Healing Platform Recovery Webhook
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$PROJECT_DIR
ExecStart=$GUNICORN --bind 0.0.0.0:5001 --workers 2 --timeout 30 --access-logfile - --error-logfile - recovery.recovery_server:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo
echo "[5/5] Enabling recovery service..."

sudo systemctl daemon-reload
sudo systemctl enable --now self-healing-recovery

echo
echo "======================================"
echo " Setup completed successfully"
echo "======================================"

echo
echo "Docker services:"
docker compose ps

echo
echo "Recovery service:"
sudo systemctl --no-pager --full status self-healing-recovery
