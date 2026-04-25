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
: "${SIMPLESAMLPHP_STORE_TYPE:=phpsession}"
: "${MEMCACHE_SERVER_HOST:=memcached}"
: "${MEMCACHE_SERVER_PORT:=11211}"

export SIMPLESAMLPHP_BASE_URL_PATH SIMPLESAMLPHP_SP_ENTITY_ID \
       SIMPLESAMLPHP_SP_PRIVATEKEY SIMPLESAMLPHP_SP_CERTIFICATE \
       SIMPLESAMLPHP_SP_WANT_ASSERTIONS_SIGNED SIMPLESAMLPHP_SP_WANT_MESSAGE_SIGNED \
       SIMPLESAMLPHP_ADMIN_PASSWORD SIMPLESAMLPHP_SECRET_SALT \
       SIMPLESAMLPHP_TECHNICAL_CONTACT_NAME SIMPLESAMLPHP_TECHNICAL_CONTACT_EMAIL \
       SIMPLESAMLPHP_TIMEZONE SIMPLESAMLPHP_LOGGING_HANDLER \
       SIMPLESAMLPHP_STORE_TYPE MEMCACHE_SERVER_HOST MEMCACHE_SERVER_PORT

# ---------------------------------------------------------------------------
# Generate Apache VirtualHost configuration from template
# Only the named variables are substituted; ${APACHE_LOG_DIR} etc. are left
# intact for Apache itself to expand at runtime.
# ---------------------------------------------------------------------------
APACHE_VARS='${DOMAIN_NAME} ${SERVER_NAME} ${SERVER_ALIAS} ${FQDN} ${WEBMASTER} ${SSL_CERTIFICATE_FILE} ${SSL_PRIVATE_KEY_FILE}'
envsubst "${APACHE_VARS}" \
    </etc/apache2/sites-available/simplesamlphp.conf.template \
    >/etc/apache2/sites-available/simplesamlphp.conf

# Enable the site (idempotent)
a2ensite simplesamlphp.conf >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# Generate SimpleSAMLphp config/config.php from template
# ---------------------------------------------------------------------------
SSMPHP_CONFIG_VARS='${SIMPLESAMLPHP_BASE_URL_PATH} ${SIMPLESAMLPHP_SECRET_SALT} ${SIMPLESAMLPHP_ADMIN_PASSWORD} ${SIMPLESAMLPHP_TECHNICAL_CONTACT_NAME} ${SIMPLESAMLPHP_TECHNICAL_CONTACT_EMAIL} ${SIMPLESAMLPHP_TIMEZONE} ${SIMPLESAMLPHP_LOGGING_HANDLER} ${SIMPLESAMLPHP_STORE_TYPE} ${MEMCACHE_SERVER_HOST} ${MEMCACHE_SERVER_PORT}'
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
    /var/cache/simplesamlphp

exec "$@"
