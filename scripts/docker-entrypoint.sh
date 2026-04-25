#!/bin/bash
set -euo pipefail

##
## docker-entrypoint.sh
##
## Maps shell/environment variables to Apache and SimpleSAMLphp configuration.
## Derived variables are computed from base variables before substitution.
##

# ---------------------------------------------------------------------------
# Apache / network defaults
# ---------------------------------------------------------------------------
: "${DOMAIN_NAME:=se.lemche.net}"
: "${SERVER_NAME:=simplesamlphp}"
: "${SERVER_ALIAS:=${SERVER_NAME}}"
: "${FQDN:=${SERVER_NAME}.${DOMAIN_NAME}}"
: "${WEBMASTER:=webmaster@${DOMAIN_NAME}}"
: "${SSL_CERTIFICATE_FILE:=/etc/ssl/certs/${FQDN}.crt}"
: "${SSL_PRIVATE_KEY_FILE:=/etc/ssl/private/${FQDN}.key}"

export DOMAIN_NAME SERVER_NAME SERVER_ALIAS FQDN WEBMASTER \
       SSL_CERTIFICATE_FILE SSL_PRIVATE_KEY_FILE

# ---------------------------------------------------------------------------
# SimpleSAMLphp defaults
# ---------------------------------------------------------------------------
: "${SIMPLESAMLPHP_BASE_URL_PATH:=https://${FQDN}/simplesaml/}"
: "${SIMPLESAMLPHP_SP_ENTITY_ID:=https://${FQDN}/simplesaml/module.php/saml/sp/metadata/default-sp}"
: "${SIMPLESAMLPHP_SP_PRIVATEKEY:=sp.key}"
: "${SIMPLESAMLPHP_SP_CERTIFICATE:=sp.crt}"
: "${SIMPLESAMLPHP_SP_WANT_ASSERTIONS_SIGNED:=true}"
: "${SIMPLESAMLPHP_SP_WANT_MESSAGE_SIGNED:=true}"
: "${SIMPLESAMLPHP_ADMIN_PASSWORD:=admin}"
if [ "${SIMPLESAMLPHP_ADMIN_PASSWORD}" = "admin" ]; then
    echo "WARNING: SIMPLESAMLPHP_ADMIN_PASSWORD is set to the insecure default 'admin'. Set a strong password via the environment variable." >&2
fi

# Use openssl to generate a cryptographically-secure salt; fail loudly if
# the tool is unavailable rather than silently falling back to a predictable
# value that would compromise token security.
if [ -z "${SIMPLESAMLPHP_SECRET_SALT:-}" ]; then
    SIMPLESAMLPHP_SECRET_SALT="$(openssl rand -hex 32)"
fi
: "${SIMPLESAMLPHP_TECHNICAL_CONTACT_NAME:=Administrator}"
: "${SIMPLESAMLPHP_TECHNICAL_CONTACT_EMAIL:=webmaster@${DOMAIN_NAME}}"
: "${SIMPLESAMLPHP_TIMEZONE:=UTC}"
: "${SIMPLESAMLPHP_LOGGING_HANDLER:=errorlog}"
: "${SIMPLESAMLPHP_LOG_DIR:=/var/simplesamlphp/log}"
: "${SIMPLESAMLPHP_STORE_TYPE:=phpsession}"
: "${MEMCACHE_SERVER_HOST:=memcached}"
: "${MEMCACHE_SERVER_PORT:=11211}"

# Cron module – secret key protects the HTTP trigger endpoint.
# Auto-generate a secure random secret when one is not supplied, just like
# SIMPLESAMLPHP_SECRET_SALT above.
if [ -z "${SIMPLESAMLPHP_CRON_SECRET:-}" ]; then
    SIMPLESAMLPHP_CRON_SECRET="$(openssl rand -hex 32)"
    echo "INFO: SIMPLESAMLPHP_CRON_SECRET was not set – auto-generated a random value." \
         "Set SIMPLESAMLPHP_CRON_SECRET explicitly in production so the cron trigger" \
         "URL stays stable across container restarts." >&2
fi

# MetaRefresh module defaults
: "${SIMPLESAMLPHP_METAREFRESH_CRON_TAG:=metarefresh}"
: "${SIMPLESAMLPHP_METAREFRESH_METADATA_URL:=}"
: "${SIMPLESAMLPHP_METAREFRESH_OUTPUT_DIR:=/var/simplesamlphp/metadata/metarefresh}"
: "${SIMPLESAMLPHP_METAREFRESH_EXPIRE_AFTER:=345600}"

# Validate that EXPIRE_AFTER is a positive integer so that the generated
# module_metarefresh.php cannot contain syntactically invalid PHP.
if ! printf '%s' "${SIMPLESAMLPHP_METAREFRESH_EXPIRE_AFTER}" | grep -qE '^[0-9]+$'; then
    echo "ERROR: SIMPLESAMLPHP_METAREFRESH_EXPIRE_AFTER must be a non-negative integer" \
         "(got '${SIMPLESAMLPHP_METAREFRESH_EXPIRE_AFTER}')." >&2
    exit 1
fi

export SIMPLESAMLPHP_BASE_URL_PATH SIMPLESAMLPHP_SP_ENTITY_ID \
       SIMPLESAMLPHP_SP_PRIVATEKEY SIMPLESAMLPHP_SP_CERTIFICATE \
       SIMPLESAMLPHP_SP_WANT_ASSERTIONS_SIGNED SIMPLESAMLPHP_SP_WANT_MESSAGE_SIGNED \
       SIMPLESAMLPHP_ADMIN_PASSWORD SIMPLESAMLPHP_SECRET_SALT \
       SIMPLESAMLPHP_TECHNICAL_CONTACT_NAME SIMPLESAMLPHP_TECHNICAL_CONTACT_EMAIL \
       SIMPLESAMLPHP_TIMEZONE SIMPLESAMLPHP_LOGGING_HANDLER SIMPLESAMLPHP_LOG_DIR \
       SIMPLESAMLPHP_STORE_TYPE MEMCACHE_SERVER_HOST MEMCACHE_SERVER_PORT \
       SIMPLESAMLPHP_CRON_SECRET SIMPLESAMLPHP_METAREFRESH_CRON_TAG \
       SIMPLESAMLPHP_METAREFRESH_METADATA_URL SIMPLESAMLPHP_METAREFRESH_OUTPUT_DIR \
       SIMPLESAMLPHP_METAREFRESH_EXPIRE_AFTER

# ---------------------------------------------------------------------------
# Per-container log directory
#
# HOSTNAME is automatically set by the container runtime to the container
# short-ID (Docker) or pod name (Kubernetes StatefulSet/Deployment), giving
# every replica a uniquely-named subdirectory on a shared volume.
#
# When SIMPLESAMLPHP_LOGGING_HANDLER=file both SimpleSAMLphp and Apache write
# into SIMPLESAMLPHP_LOG_DIR_INSTANCE.  For all other handlers Apache falls
# back to /var/log/apache2 (symlinked to /dev/stdout and /dev/stderr in the
# base image) so that 'docker logs' continues to show Apache output.
# ---------------------------------------------------------------------------
SIMPLESAMLPHP_LOG_DIR_INSTANCE="${SIMPLESAMLPHP_LOG_DIR}/${HOSTNAME}"

if [ "${SIMPLESAMLPHP_LOGGING_HANDLER}" = "file" ]; then
    APACHE_LOG_DIR_INSTANCE="${SIMPLESAMLPHP_LOG_DIR_INSTANCE}/apache"
else
    APACHE_LOG_DIR_INSTANCE="/var/log/apache2"
fi

export SIMPLESAMLPHP_LOG_DIR_INSTANCE APACHE_LOG_DIR_INSTANCE

# ---------------------------------------------------------------------------
# Generate Apache VirtualHost configuration from template
# Only the named variables are substituted; ${APACHE_LOG_DIR} etc. are left
# intact for Apache itself to expand at runtime.
# ---------------------------------------------------------------------------
APACHE_VARS='${DOMAIN_NAME} ${SERVER_NAME} ${SERVER_ALIAS} ${FQDN} ${WEBMASTER} ${SSL_CERTIFICATE_FILE} ${SSL_PRIVATE_KEY_FILE} ${APACHE_LOG_DIR_INSTANCE}'
envsubst "${APACHE_VARS}" \
    </etc/apache2/sites-available/simplesamlphp.conf.template \
    >/etc/apache2/sites-available/simplesamlphp.conf

# Enable the site (idempotent)
a2ensite simplesamlphp.conf >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# Generate SimpleSAMLphp config/config.php from template
# ---------------------------------------------------------------------------
SSMPHP_CONFIG_VARS='${SIMPLESAMLPHP_BASE_URL_PATH} ${SIMPLESAMLPHP_SECRET_SALT} ${SIMPLESAMLPHP_ADMIN_PASSWORD} ${SIMPLESAMLPHP_TECHNICAL_CONTACT_NAME} ${SIMPLESAMLPHP_TECHNICAL_CONTACT_EMAIL} ${SIMPLESAMLPHP_TIMEZONE} ${SIMPLESAMLPHP_LOGGING_HANDLER} ${SIMPLESAMLPHP_STORE_TYPE} ${MEMCACHE_SERVER_HOST} ${MEMCACHE_SERVER_PORT} ${SIMPLESAMLPHP_METAREFRESH_OUTPUT_DIR} ${SIMPLESAMLPHP_LOG_DIR_INSTANCE}'
envsubst "${SSMPHP_CONFIG_VARS}" \
    </var/simplesamlphp/config/config.php.template \
    >/var/simplesamlphp/config/config.php

# ---------------------------------------------------------------------------
# Generate SimpleSAMLphp config/authsources.php from template
# ---------------------------------------------------------------------------
SSMPHP_AUTH_VARS='${SIMPLESAMLPHP_SP_ENTITY_ID} ${SIMPLESAMLPHP_SP_PRIVATEKEY} ${SIMPLESAMLPHP_SP_CERTIFICATE} ${SIMPLESAMLPHP_SP_WANT_ASSERTIONS_SIGNED} ${SIMPLESAMLPHP_SP_WANT_MESSAGE_SIGNED}'
envsubst "${SSMPHP_AUTH_VARS}" \
    </var/simplesamlphp/config/authsources.php.template \
    >/var/simplesamlphp/config/authsources.php

# ---------------------------------------------------------------------------
# Generate SimpleSAMLphp config/module_cron.php from template
# ---------------------------------------------------------------------------
SSMPHP_CRON_VARS='${SIMPLESAMLPHP_CRON_SECRET} ${SIMPLESAMLPHP_METAREFRESH_CRON_TAG}'
envsubst "${SSMPHP_CRON_VARS}" \
    </var/simplesamlphp/config/module_cron.php.template \
    >/var/simplesamlphp/config/module_cron.php

# ---------------------------------------------------------------------------
# Generate SimpleSAMLphp config/module_metarefresh.php from template
# ---------------------------------------------------------------------------
SSMPHP_METAREFRESH_VARS='${SIMPLESAMLPHP_METAREFRESH_CRON_TAG} ${SIMPLESAMLPHP_METAREFRESH_METADATA_URL} ${SIMPLESAMLPHP_METAREFRESH_OUTPUT_DIR} ${SIMPLESAMLPHP_METAREFRESH_EXPIRE_AFTER}'
envsubst "${SSMPHP_METAREFRESH_VARS}" \
    </var/simplesamlphp/config/module_metarefresh.php.template \
    >/var/simplesamlphp/config/module_metarefresh.php

# ---------------------------------------------------------------------------
# Ensure the metarefresh output directory exists so SimpleSAMLphp can write
# converted metadata files there on the first cron run.
# ---------------------------------------------------------------------------
mkdir -p "${SIMPLESAMLPHP_METAREFRESH_OUTPUT_DIR}"

# ---------------------------------------------------------------------------
# Create the per-container log directory.  All replicas sharing a single
# volume each get their own sub-directory named after the container's
# HOSTNAME (container short-ID in Docker; pod name in Kubernetes), making
# every replica uniquely identifiable in the log tree.
# ---------------------------------------------------------------------------
mkdir -p "${SIMPLESAMLPHP_LOG_DIR_INSTANCE}"
if [ "${SIMPLESAMLPHP_LOGGING_HANDLER}" = "file" ]; then
    mkdir -p "${APACHE_LOG_DIR_INSTANCE}"
fi

# ---------------------------------------------------------------------------
# If a bind-mounted saml20-idp-remote.php is not present, use the default
# ---------------------------------------------------------------------------
if [ ! -f /var/simplesamlphp/metadata/saml20-idp-remote.php ]; then
    cp /var/simplesamlphp/metadata/saml20-idp-remote.php.default \
       /var/simplesamlphp/metadata/saml20-idp-remote.php
fi

# ---------------------------------------------------------------------------
# Fix ownership so Apache (www-data) can read all SimpleSAMLphp files
# ---------------------------------------------------------------------------
chown -R www-data:www-data \
    /var/simplesamlphp/config \
    /var/simplesamlphp/metadata \
    /var/simplesamlphp/cert \
    /var/simplesamlphp/log \
    /var/cache/simplesamlphp \
    "${SIMPLESAMLPHP_METAREFRESH_OUTPUT_DIR}" \
    "${SIMPLESAMLPHP_LOG_DIR_INSTANCE}"

exec "$@"
