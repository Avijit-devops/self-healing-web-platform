#!/bin/bash

set -euo pipefail

CONTAINER="self-healing-app"

if docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -q "true"; then
    echo "$(date -Is) - $CONTAINER is already running"
    exit 0
fi

echo "$(date -Is) - $CONTAINER is down. Starting container..."
docker start "$CONTAINER"

echo "$(date -Is) - $CONTAINER recovery command completed"
