#!/bin/bash
set -euo pipefail

##
## metarefresh.sh
##
## Triggers the SimpleSAMLphp metarefresh cron run by calling the cron module's
## HTTP endpoint on localhost.  The script can be used in two ways:
##
## 1. Ad-hoc standalone container (one-shot run, then exit):
##
##      docker run --rm \
##        -e SIMPLESAMLPHP_CRON_SECRET=<secret> \
##        -e SIMPLESAMLPHP_METAREFRESH_METADATA_URL=https://federation.example.org/metadata.xml \
##        [-e SIMPLESAMLPHP_METAREFRESH_CRON_TAG=metarefresh] \
##        [-v /path/to/cert:/var/simplesamlphp/cert:ro] \
##        [-v /path/to/metadata:/var/simplesamlphp/metadata] \
##        <image> metarefresh.sh
##
##    The docker-entrypoint.sh runs first (via ENTRYPOINT), generating all
##    SimpleSAMLphp and Apache configuration files.  This script then starts
##    Apache temporarily, triggers the refresh, and exits.
##
## 2. Against a running container (exec):
##
##      docker exec <container-name> metarefresh.sh
##
##    Apache is already running inside the container so this script simply
##    calls the cron endpoint and exits.
##

# ---------------------------------------------------------------------------
# Defaults (overridden by the environment when set in the entrypoint)
# ---------------------------------------------------------------------------
: "${SIMPLESAMLPHP_METAREFRESH_CRON_TAG:=metarefresh}"
: "${SIMPLESAMLPHP_CRON_SECRET:=}"

if [ -z "${SIMPLESAMLPHP_CRON_SECRET}" ]; then
    echo "[metarefresh] ERROR: SIMPLESAMLPHP_CRON_SECRET is not set." >&2
    echo "[metarefresh]        Set it via the environment variable or let the" >&2
    echo "[metarefresh]        entrypoint auto-generate it (check the logs for" >&2
    echo "[metarefresh]        the generated value when running interactively)." >&2
    exit 1
fi

CRON_URL="http://127.0.0.1/simplesaml/module.php/cron/run/${SIMPLESAMLPHP_METAREFRESH_CRON_TAG}/${SIMPLESAMLPHP_CRON_SECRET}"

# ---------------------------------------------------------------------------
# Detect whether Apache is already running (docker exec case)
# ---------------------------------------------------------------------------
APACHE_STARTED=0
APACHE_PID=""
APACHE_RUNNING=0

APACHE_PID_FILE="/var/run/apache2/apache2.pid"
if [ -f "${APACHE_PID_FILE}" ]; then
    APACHE_PID_CONTENT=$(cat "${APACHE_PID_FILE}" 2>/dev/null || true)
    # Validate the PID file contains only digits before trusting it
    if printf '%s' "${APACHE_PID_CONTENT}" | grep -qE '^[0-9]+$' && kill -0 "${APACHE_PID_CONTENT}" 2>/dev/null; then
        echo "[metarefresh] Apache is already running (PID ${APACHE_PID_CONTENT})."
        APACHE_RUNNING=1
    fi
fi

if [ "${APACHE_RUNNING}" -eq 0 ]; then
    echo "[metarefresh] Starting Apache temporarily..."
    # Start Apache in the foreground as a background process
    apache2 -DFOREGROUND &
    APACHE_PID=$!
    APACHE_STARTED=1

    # Wait up to 30 seconds for Apache to accept connections
    for i in $(seq 1 30); do
        if curl -sf --max-time 2 "http://127.0.0.1/simplesaml/" > /dev/null 2>&1; then
            echo "[metarefresh] Apache is ready (${i}s)."
            break
        fi
        if [ "${i}" -eq 30 ]; then
            echo "[metarefresh] ERROR: Apache failed to start within 30 seconds." >&2
            kill "${APACHE_PID}" 2>/dev/null || true
            wait "${APACHE_PID}" 2>/dev/null || true
            exit 1
        fi
        sleep 1
    done
fi

# ---------------------------------------------------------------------------
# Trigger the cron / metarefresh endpoint
# ---------------------------------------------------------------------------
echo "[metarefresh] Triggering cron tag '${SIMPLESAMLPHP_METAREFRESH_CRON_TAG}'..."

RESPONSE_BODY=$(mktemp)
HTTP_STATUS=$(curl -s -o "${RESPONSE_BODY}" -w '%{http_code}' "${CRON_URL}")

# ---------------------------------------------------------------------------
# Stop the temporarily-started Apache (if we started it)
# ---------------------------------------------------------------------------
if [ "${APACHE_STARTED}" -eq 1 ]; then
    kill "${APACHE_PID}" 2>/dev/null || true
    wait "${APACHE_PID}" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Evaluate the result
# ---------------------------------------------------------------------------
if [ "${HTTP_STATUS}" = "200" ]; then
    echo "[metarefresh] Completed successfully (HTTP 200)."
    rm -f "${RESPONSE_BODY}"
    exit 0
else
    echo "[metarefresh] ERROR: cron endpoint returned HTTP ${HTTP_STATUS}." >&2
    echo "[metarefresh] Response body:" >&2
    cat "${RESPONSE_BODY}" >&2
    rm -f "${RESPONSE_BODY}"
    exit 1
fi
