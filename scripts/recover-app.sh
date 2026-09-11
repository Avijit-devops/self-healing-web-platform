#!/bin/bash

set -euo pipefail

CONTAINER="self-healing-app"

if ! command -v docker >/dev/null 2>&1; then
    echo "$(date -Is) - ERROR: Docker is not installed or not in PATH"
    exit 1
fi

if ! docker inspect "$CONTAINER" >/dev/null 2>&1; then
    echo "$(date -Is) - ERROR: Container '$CONTAINER' does not exist"
    exit 1
fi

if docker inspect -f '{{.State.Running}}' "$CONTAINER" | grep -q "true"; then
    echo "$(date -Is) - $CONTAINER is already running"
    exit 0
fi

echo "$(date -Is) - $CONTAINER is down. Starting container..."
docker start "$CONTAINER"

echo "$(date -Is) - $CONTAINER recovery command completed"
