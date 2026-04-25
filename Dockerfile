FROM composer:2 AS composer
FROM php:8.3-apache

LABEL org.opencontainers.image.title="docker-simplesamlphp" \
      org.opencontainers.image.description="SimpleSAMLphp running on Apache with PHP" \
      org.opencontainers.image.url="https://github.com/atterdag/docker-simplesamlphp" \
      org.opencontainers.image.source="https://github.com/atterdag/docker-simplesamlphp"

# ---------------------------------------------------------------------------
# SimpleSAMLphp version – override at build time with:
#   docker build --build-arg SIMPLESAMLPHP_VERSION=2.x.y ...
# ---------------------------------------------------------------------------
ARG SIMPLESAMLPHP_VERSION=2.5.0

# ---------------------------------------------------------------------------
# Composer binary from the official Composer image
# ---------------------------------------------------------------------------
COPY --from=composer /usr/bin/composer /usr/bin/composer

# ---------------------------------------------------------------------------
# System packages
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        gettext-base \
        git \
        libicu-dev \
        libmemcached-dev \
        libzip-dev \
        unzip \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# PHP extensions required by SimpleSAMLphp 2.x
# ---------------------------------------------------------------------------
RUN docker-php-ext-install \
        intl \
        zip

# ---------------------------------------------------------------------------
# PHP memcached extension (for SimpleSAMLphp memcache session store)
# ---------------------------------------------------------------------------
RUN pecl install memcached \
    && docker-php-ext-enable memcached

# ---------------------------------------------------------------------------
# Apache modules
# ---------------------------------------------------------------------------
RUN a2enmod \
        deflate \
        expires \
        headers \
        http2 \
        rewrite \
        ssl \
        socache_shmcb \
        unique_id

# ---------------------------------------------------------------------------
# Download and install SimpleSAMLphp
# The full-release tarball includes all optional modules.
# ---------------------------------------------------------------------------
RUN set -eux; \
    mkdir -p /var/simplesamlphp; \
    curl -fsSL \
        "https://github.com/simplesamlphp/simplesamlphp/releases/download/v${SIMPLESAMLPHP_VERSION}/simplesamlphp-${SIMPLESAMLPHP_VERSION}-full.tar.gz" \
        | tar -xz --strip-components=1 -C /var/simplesamlphp; \
    # Create required runtime directories
    mkdir -p \
        /var/simplesamlphp/cert \
        /var/simplesamlphp/data \
        /var/simplesamlphp/log \
        /var/cache/simplesamlphp

# ---------------------------------------------------------------------------
# Install OIDC / OAuth2 authentication module (supports OpenID Connect SP)
# cirrusidentity/simplesamlphp-module-authoauth2 v4.x supports SSP 2.x.
# ---------------------------------------------------------------------------
RUN cd /var/simplesamlphp \
    && composer require \
        cirrusidentity/simplesamlphp-module-authoauth2 \
        --no-interaction \
        --no-progress \
        --prefer-dist \
    && composer clear-cache

# ---------------------------------------------------------------------------
# Copy configuration templates
# (envsubst fills in environment variables at container start)
# ---------------------------------------------------------------------------
COPY conf/simplesamlphp/config.php.template \
     /var/simplesamlphp/config/config.php.template
COPY conf/simplesamlphp/authsources.php.template \
     /var/simplesamlphp/config/authsources.php.template
COPY conf/simplesamlphp/module_cron.php.template \
     /var/simplesamlphp/config/module_cron.php.template
COPY conf/simplesamlphp/module_metarefresh.php.template \
     /var/simplesamlphp/config/module_metarefresh.php.template

# ---------------------------------------------------------------------------
# Copy Apache VirtualHost template
# ---------------------------------------------------------------------------
COPY conf/apache/simplesamlphp.conf.template \
     /etc/apache2/sites-available/simplesamlphp.conf.template

# ---------------------------------------------------------------------------
# Copy MPM prefork tuning (overrides the base-image defaults, which are
# sized for ~1 GB RAM; this configuration targets 4 GB RAM)
# ---------------------------------------------------------------------------
COPY conf/apache/mpm_prefork.conf \
     /etc/apache2/mods-available/mpm_prefork.conf

# ---------------------------------------------------------------------------
# Copy default IdP metadata (overridable via volume/ConfigMap mount)
# ---------------------------------------------------------------------------
COPY metadata/saml20-idp-remote.php \
     /var/simplesamlphp/metadata/saml20-idp-remote.php.default

# ---------------------------------------------------------------------------
# Copy and register the entrypoint script and the ad-hoc metarefresh script
# ---------------------------------------------------------------------------
COPY scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY scripts/metarefresh.sh       /usr/local/bin/metarefresh.sh
RUN chmod +x \
        /usr/local/bin/docker-entrypoint.sh \
        /usr/local/bin/metarefresh.sh

# ---------------------------------------------------------------------------
# Copy web application files (secure example page, error pages, stylesheet)
# ---------------------------------------------------------------------------
COPY www/ /var/www/html/

# ---------------------------------------------------------------------------
# Copy custom SimpleSAMLphp theme module
# ---------------------------------------------------------------------------
COPY modules/customtheme/ /var/simplesamlphp/modules/customtheme/

# ---------------------------------------------------------------------------
# Apache site configuration
# ---------------------------------------------------------------------------
RUN a2dissite 000-default

# ---------------------------------------------------------------------------
# Permissions
# ---------------------------------------------------------------------------
RUN chown -R www-data:www-data \
        /var/simplesamlphp \
        /var/cache/simplesamlphp

# ---------------------------------------------------------------------------
# Default environment variables
# Derived variables (FQDN, WEBMASTER, …) are computed in the entrypoint.
# ---------------------------------------------------------------------------

# Apache / network
ENV DOMAIN_NAME=se.lemche.net \
    SERVER_NAME=simplesamlphp

# SimpleSAMLphp – SP key/cert filenames (relative to certdir /var/simplesamlphp/cert/)
ENV SIMPLESAMLPHP_SP_PRIVATEKEY=sp.key \
    SIMPLESAMLPHP_SP_CERTIFICATE=sp.crt

# SimpleSAMLphp – security defaults
ENV SIMPLESAMLPHP_SP_WANT_ASSERTIONS_SIGNED=true \
    SIMPLESAMLPHP_SP_WANT_MESSAGE_SIGNED=true

# SimpleSAMLphp – admin
ENV SIMPLESAMLPHP_ADMIN_PASSWORD=admin \
    SIMPLESAMLPHP_TECHNICAL_CONTACT_NAME=Administrator

# SimpleSAMLphp – runtime
# SIMPLESAMLPHP_STORE_TYPE defaults to 'memcache' so that sessions are shared
# across replicas.  Set MEMCACHE_SERVER_HOST / MEMCACHE_SERVER_PORT to point at
# your memcached instance, or override SIMPLESAMLPHP_STORE_TYPE to 'phpsession'
# for single-node deployments that have no memcached service available.
ENV SIMPLESAMLPHP_TIMEZONE=UTC \
    SIMPLESAMLPHP_LOGGING_HANDLER=errorlog \
    SIMPLESAMLPHP_LOG_DIR=/var/simplesamlphp/log \
    SIMPLESAMLPHP_STORE_TYPE=memcache \
    MEMCACHE_SERVER_HOST=memcached \
    MEMCACHE_SERVER_PORT=11211

# SimpleSAMLphp – automated metadata management (metarefresh + cron modules)
# SIMPLESAMLPHP_CRON_SECRET is intentionally left empty here; the entrypoint
# auto-generates a cryptographically-secure random value when not explicitly
# supplied.  Set a stable value in production so that the cron URL remains
# predictable across container restarts.
ENV SIMPLESAMLPHP_CRON_SECRET="" \
    SIMPLESAMLPHP_METAREFRESH_CRON_TAG=metarefresh \
    SIMPLESAMLPHP_METAREFRESH_METADATA_URL="" \
    SIMPLESAMLPHP_METAREFRESH_OUTPUT_DIR=/var/simplesamlphp/metadata/metarefresh \
    SIMPLESAMLPHP_METAREFRESH_EXPIRE_AFTER=345600

# SimpleSAMLphp – OpenID Connect (OIDC) Relying Party configuration
# These are intentionally left empty; set them at runtime to enable the
# oidc-sp authentication source.  See authsources.php.template for details.
ENV SIMPLESAMLPHP_OIDC_ISSUER="" \
    SIMPLESAMLPHP_OIDC_CLIENT_ID="" \
    SIMPLESAMLPHP_OIDC_CLIENT_SECRET=""

# ---------------------------------------------------------------------------
# Volumes
#
#  /var/simplesamlphp/log      – SimpleSAMLphp and Apache log files
#                                (one sub-directory per container, named by
#                                 $HOSTNAME; mount a shared volume here to
#                                 collect logs from all replicas in one place)
#  /var/simplesamlphp/metadata  – IdP metadata (ConfigMap or bind-mount)
#  /var/simplesamlphp/cert      – SP signing key + cert (Secret or bind-mount)
#  /etc/ssl/certs               – Apache TLS certificate (Secret or bind-mount)
#  /etc/ssl/private             – Apache TLS private key (Secret or bind-mount)
# ---------------------------------------------------------------------------
VOLUME ["/var/simplesamlphp/log", "/var/simplesamlphp/metadata", \
        "/var/simplesamlphp/cert", "/etc/ssl/certs", "/etc/ssl/private"]

EXPOSE 80 443

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
