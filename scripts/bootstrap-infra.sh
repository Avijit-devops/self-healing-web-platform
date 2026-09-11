#!/usr/bin/env bash

# ============================================================
# Self-Healing DevOps Platform
# Bootstrap / Infrastructure Readiness Script
#
# Tested target:
#   Ubuntu 22.04 / 24.04
#
# Purpose:
#   - Check VM resources
#   - Install missing DevOps prerequisites
#   - Install Docker + Compose if required
#   - Install Git, Ansible, Terraform and utilities
#   - Check important ports
#   - Create project directory structure
#
# IMPORTANT:
#   This script DOES NOT:
#   - remove existing Docker containers
#   - remove Docker images
#   - remove Docker volumes
#   - remove Docker networks
#   - restart existing application containers
# ============================================================

set -Eeuo pipefail

# -----------------------------
# Configuration
# -----------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${PROJECT_DIR}/logs"
REPORT_FILE="${PROJECT_DIR}/logs/bootstrap-report.txt"

MIN_CPU=4
MIN_RAM_GB=8
MIN_DISK_GB=30

REQUIRED_PORTS=(
    8080
    3000
    9090
    9093
    9100
)

# -----------------------------
# Colors
# -----------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# -----------------------------
# Logging
# -----------------------------

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

die() {
    error "$1"
    exit 1
}

# -----------------------------
# Root check
# -----------------------------

if [[ "${EUID}" -eq 0 ]]; then
    die "Do not run this script directly as root. Run it as your normal user."
fi

if ! sudo -n true 2>/dev/null; then
    log "Sudo access is required."
    sudo -v || die "Unable to obtain sudo privileges."
fi

# -----------------------------
# Detect OS
# -----------------------------

log "Checking operating system..."

if [[ ! -f /etc/os-release ]]; then
    die "/etc/os-release not found."
fi

source /etc/os-release

echo
echo "=========================================="
echo " Operating System"
echo "=========================================="
echo "Distribution : ${PRETTY_NAME}"
echo "Architecture  : $(uname -m)"
echo "Kernel        : $(uname -r)"
echo

if [[ "${ID}" != "ubuntu" ]]; then
    warning "This script is designed primarily for Ubuntu."
fi

# -----------------------------
# CPU check
# -----------------------------

CPU_COUNT="$(nproc)"

echo "CPU           : ${CPU_COUNT} vCPU"

if (( CPU_COUNT >= MIN_CPU )); then
    success "CPU requirement satisfied (${CPU_COUNT} >= ${MIN_CPU})"
else
    error "CPU requirement NOT satisfied (${CPU_COUNT} < ${MIN_CPU})"
    exit 1
fi

# -----------------------------
# RAM check
# -----------------------------

RAM_KB="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
RAM_GB=$(( RAM_KB / 1024 / 1024 ))

echo "RAM           : ${RAM_GB} GB"

if (( RAM_GB >= MIN_RAM_GB )); then
    success "RAM requirement satisfied (${RAM_GB} GB >= ${MIN_RAM_GB} GB)"
else
    error "RAM requirement NOT satisfied (${RAM_GB} GB < ${MIN_RAM_GB} GB)"
    exit 1
fi

# -----------------------------
# Disk check
# -----------------------------

DISK_AVAILABLE_KB="$(df -Pk "${HOME}" | awk 'NR==2 {print $4}')"
DISK_AVAILABLE_GB=$(( DISK_AVAILABLE_KB / 1024 / 1024 ))

echo "Free Disk     : ${DISK_AVAILABLE_GB} GB"

if (( DISK_AVAILABLE_GB >= MIN_DISK_GB )); then
    success "Disk requirement satisfied (${DISK_AVAILABLE_GB} GB >= ${MIN_DISK_GB} GB)"
else
    error "Disk requirement NOT satisfied (${DISK_AVAILABLE_GB} GB < ${MIN_DISK_GB} GB)"
    exit 1
fi

# -----------------------------
# Virtualization
# -----------------------------

echo
echo "=========================================="
echo " Virtualization"
echo "=========================================="

if command -v systemd-detect-virt >/dev/null 2>&1; then
    VIRT="$(systemd-detect-virt || true)"
    echo "Virtualization : ${VIRT:-none}"
fi

# -----------------------------
# Update apt metadata
# -----------------------------

log "Updating apt package information..."

sudo apt-get update -y

# -----------------------------
# Install basic packages
# -----------------------------

BASE_PACKAGES=(
    ca-certificates
    curl
    wget
    gnupg
    lsb-release
    apt-transport-https
    software-properties-common
    git
    jq
    unzip
    tree
    htop
    vim
    net-tools
    iproute2
    dnsutils
    ncdu
    python3
    python3-pip
    python3-venv
    openssh-client
)

log "Installing missing base packages..."

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    "${BASE_PACKAGES[@]}"

success "Base packages installed."

# -----------------------------
# Docker installation
# -----------------------------

echo
echo "=========================================="
echo " Docker"
echo "=========================================="

if command -v docker >/dev/null 2>&1; then

    success "Docker already installed."

    docker --version || true

else

    log "Docker not found. Installing Docker..."

    sudo install -m 0755 -d /etc/apt/keyrings

    if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
        sudo curl -fsSL \
            https://download.docker.com/linux/ubuntu/gpg \
            -o /etc/apt/keyrings/docker.asc

        sudo chmod a+r /etc/apt/keyrings/docker.asc
    fi

    ARCH="$(dpkg --print-architecture)"

    echo \
      "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] \
      https://download.docker.com/linux/ubuntu \
      ${VERSION_CODENAME} stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update -y

    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    sudo systemctl enable --now docker

    success "Docker installed."
fi

# -----------------------------
# Docker service
# -----------------------------

if systemctl is-active --quiet docker; then
    success "Docker service is running."
else
    warning "Docker service is not running."

    log "Attempting to start Docker..."

    sudo systemctl start docker

    if systemctl is-active --quiet docker; then
        success "Docker service started."
    else
        error "Docker could not be started."
    fi
fi

# -----------------------------
# Docker Compose
# -----------------------------

echo
echo "=========================================="
echo " Docker Compose"
echo "=========================================="

if docker compose version >/dev/null 2>&1; then
    success "Docker Compose plugin is available."
    docker compose version
else
    warning "Docker Compose plugin is unavailable."
fi

# -----------------------------
# Docker user permissions
# -----------------------------

if groups "${USER}" | grep -qw docker; then
    success "User '${USER}' is already in the docker group."
else
    log "Adding '${USER}' to docker group..."

    sudo usermod -aG docker "${USER}"

    warning "Docker group membership has been added."
    warning "A new login session may be required before 'docker' works without sudo."
fi

# -----------------------------
# Ansible
# -----------------------------

echo
echo "=========================================="
echo " Ansible"
echo "=========================================="

if command -v ansible >/dev/null 2>&1; then

    success "Ansible already installed."
    ansible --version | head -n 1

else

    log "Installing Ansible..."

    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ansible

    success "Ansible installed."
    ansible --version | head -n 1
fi

# -----------------------------
# Terraform
# -----------------------------

echo
echo "=========================================="
echo " Terraform"
echo "=========================================="

if command -v terraform >/dev/null 2>&1; then

    success "Terraform already installed."
    terraform version | head -n 1

else

    log "Terraform not found. Installing HashiCorp repository..."

    sudo install -m 0755 -d /etc/apt/keyrings

    if [[ ! -f /etc/apt/keyrings/hashicorp-archive-keyring.gpg ]]; then

        curl -fsSL \
            https://apt.releases.hashicorp.com/gpg | \
            sudo gpg --dearmor \
            -o /etc/apt/keyrings/hashicorp-archive-keyring.gpg

        sudo chmod 644 \
            /etc/apt/keyrings/hashicorp-archive-keyring.gpg
    fi

    echo \
      "deb [signed-by=/etc/apt/keyrings/hashicorp-archive-keyring.gpg] \
      https://apt.releases.hashicorp.com \
      ${VERSION_CODENAME} main" | \
      sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null

    sudo apt-get update -y

    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y terraform

    success "Terraform installed."
    terraform version | head -n 1
fi

# -----------------------------
# Trivy
# -----------------------------

echo
echo "=========================================="
echo " Trivy"
echo "=========================================="

if command -v trivy >/dev/null 2>&1; then

    success "Trivy already installed."
    trivy --version | head -n 1

else

    log "Trivy not found."

    # Try Ubuntu package first
    if apt-cache show trivy >/dev/null 2>&1; then

        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y trivy

        success "Trivy installed from apt."

    else

        warning "Trivy is not available from the current Ubuntu repositories."
        warning "We will install it later through the project tooling."
    fi
fi

# -----------------------------
# Tool verification
# -----------------------------

echo
echo "=========================================="
echo " Tool Verification"
echo "=========================================="

TOOLS=(
    git
    curl
    jq
    tree
    python3
    ansible
    terraform
)

for tool in "${TOOLS[@]}"; do

    if command -v "${tool}" >/dev/null 2>&1; then
        success "${tool}: available"
    else
        warning "${tool}: NOT AVAILABLE"
    fi

done

if command -v docker >/dev/null 2>&1; then
    success "docker: available"
else
    warning "docker: NOT AVAILABLE"
fi

if docker compose version >/dev/null 2>&1; then
    success "docker compose: available"
else
    warning "docker compose: NOT AVAILABLE"
fi

# -----------------------------
# Existing Docker workloads
# -----------------------------

echo
echo "=========================================="
echo " Existing Docker Workloads"
echo "=========================================="

if docker info >/dev/null 2>&1; then

    CONTAINER_COUNT="$(docker ps -q | wc -l)"

    echo "Running containers: ${CONTAINER_COUNT}"

    if (( CONTAINER_COUNT > 0 )); then

        echo
        echo "Existing containers:"
        docker ps \
            --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'

        echo
        warning "Existing Docker workloads detected."
        warning "The bootstrap script will NOT modify them."

    else

        success "No running Docker containers detected."

    fi

else

    warning "Unable to query Docker without a new login session."
fi

# -----------------------------
# Docker networks
# -----------------------------

echo
echo "=========================================="
echo " Docker Networks"
echo "=========================================="

if docker info >/dev/null 2>&1; then
    docker network ls
fi

# -----------------------------
# Port checks
# -----------------------------

echo
echo "=========================================="
echo " Required Port Check"
echo "=========================================="

echo "Ports planned for the project:"
echo

for port in "${REQUIRED_PORTS[@]}"; do

    if sudo ss -lntup | grep -qE ":${port}([[:space:]]|$)"; then

        warning "Port ${port}: IN USE"

        sudo ss -lntup | grep -E ":${port}([[:space:]]|$)" || true

    else

        success "Port ${port}: AVAILABLE"

    fi

done

# -----------------------------
# Create project structure
# -----------------------------

echo
echo "=========================================="
echo " Project Structure"
echo "=========================================="

mkdir -p "${PROJECT_DIR}"

mkdir -p \
    "${PROJECT_DIR}/app" \
    "${PROJECT_DIR}/terraform" \
    "${PROJECT_DIR}/ansible/inventory" \
    "${PROJECT_DIR}/ansible/playbooks" \
    "${PROJECT_DIR}/ansible/roles" \
    "${PROJECT_DIR}/monitoring/prometheus" \
    "${PROJECT_DIR}/monitoring/grafana/dashboards" \
    "${PROJECT_DIR}/monitoring/grafana/provisioning" \
    "${PROJECT_DIR}/scripts" \
    "${PROJECT_DIR}/docs" \
    "${PROJECT_DIR}/runbooks" \
    "${PROJECT_DIR}/.github/workflows" \
    "${LOG_DIR}"

success "Project directories created."

# -----------------------------
# Create .gitignore
# -----------------------------

GITIGNORE="${PROJECT_DIR}/.gitignore"

if [[ ! -f "${GITIGNORE}" ]]; then

cat > "${GITIGNORE}" <<'EOF'
# Terraform
.terraform/
*.tfstate
*.tfstate.*
crash.log
crash.*.log
*.tfvars
*.tfvars.json

# Ansible
*.retry

# Python
__pycache__/
*.py[cod]
.venv/
venv/

# Environment
.env
.env.*

# Logs
logs/
*.log

# OS
.DS_Store
Thumbs.db
EOF

success ".gitignore created."

else

    success ".gitignore already exists."

fi

# -----------------------------
# System information report
# -----------------------------

cat > "${REPORT_FILE}" <<EOF
==========================================
Self-Healing DevOps Platform
Bootstrap Report
==========================================

Date:
$(date)

Hostname:
$(hostname)

Operating System:
${PRETTY_NAME}

Kernel:
$(uname -r)

Architecture:
$(uname -m)

CPU:
${CPU_COUNT}

RAM:
${RAM_GB} GB

Available Disk:
${DISK_AVAILABLE_GB} GB

Virtualization:
$(systemd-detect-virt 2>/dev/null || echo "unknown")

Docker:
$(docker --version 2>/dev/null || echo "not available")

Docker Compose:
$(docker compose version 2>/dev/null || echo "not available")

Terraform:
$(terraform version 2>/dev/null | head -n 1 || echo "not available")

Ansible:
$(ansible --version 2>/dev/null | head -n 1 || echo "not available")

Git:
$(git --version 2>/dev/null || echo "not available")

Python:
$(python3 --version 2>/dev/null || echo "not available")

==========================================
EOF

# -----------------------------
# Final summary
# -----------------------------

echo
echo "=========================================="
echo " Bootstrap Complete"
echo "=========================================="

success "VM passed the minimum infrastructure requirements."

echo
echo "Project directory:"
echo "${PROJECT_DIR}"

echo
echo "Bootstrap report:"
echo "${REPORT_FILE}"

echo
echo "Installed/verified:"
echo "  - Docker"
echo "  - Docker Compose"
echo "  - Git"
echo "  - Ansible"
echo "  - Terraform"
echo "  - Python3"
echo "  - curl"
echo "  - jq"
echo "  - tree"
echo "  - htop"
echo "  - networking utilities"

echo
warning "If this is the first time your user was added to the docker group:"
warning "log out and log back in before running Docker without sudo."

echo
log "IMPORTANT:"
echo "Existing Docker containers/networks/volumes were not removed or modified."

echo
success "Environment preparation finished."
echo "Next step: build the application and Docker health-check layer."

