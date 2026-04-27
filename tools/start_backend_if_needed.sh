#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)}"
API_SCHEME="${JUNIORGLOBE_API_SCHEME:-}"
API_HOST="${JUNIORGLOBE_API_HOST:-}"
LOWER_HOST="$(printf "%s" "$API_HOST" | tr '[:upper:]' '[:lower:]')"

log() {
    printf '[JuniorGlobe] %s\n' "$1"
}

if [ -z "$API_HOST" ]; then
    log "No backend host configured. Skipping backend pre-action."
    exit 0
fi

case "$LOWER_HOST" in
    localhost*|127.0.0.1*|0.0.0.0*)
        ;;
    *)
        log "Remote backend configured (${API_SCHEME:-https}://$API_HOST). Skipping local backend startup."
        exit 0
        ;;
esac

HOST_ONLY="${LOWER_HOST%%/*}"
HOST_NAME="${HOST_ONLY%%:*}"
PORT="${HOST_ONLY#*:}"

if [ "$PORT" = "$HOST_ONLY" ] || [ -z "$PORT" ]; then
    case "$API_SCHEME" in
        https)
            PORT=443
            ;;
        *)
            PORT=80
            ;;
    esac
fi

if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    log "Backend already listening on port $PORT. Reusing existing process."
    exit 0
fi

if [ -x "$PROJECT_DIR/backend/server.js" ]; then
    log "Starting local backend from backend/server.js."
    nohup node "$PROJECT_DIR/backend/server.js" >/tmp/juniorglobe-backend.log 2>&1 &
    exit 0
fi

if [ -f "$PROJECT_DIR/backend/server.js" ]; then
    log "Starting local backend from backend/server.js."
    nohup node "$PROJECT_DIR/backend/server.js" >/tmp/juniorglobe-backend.log 2>&1 &
    exit 0
fi

if [ -f "$PROJECT_DIR/server.js" ]; then
    log "Starting local backend from server.js."
    nohup node "$PROJECT_DIR/server.js" >/tmp/juniorglobe-backend.log 2>&1 &
    exit 0
fi

if [ -f "$PROJECT_DIR/package.json" ]; then
    log "Local backend requested but no known server entrypoint was found. Leaving build unblocked."
    exit 0
fi

log "Local backend requested for $HOST_NAME:$PORT, but this repo does not contain a local backend launcher. Leaving build unblocked."
exit 0
