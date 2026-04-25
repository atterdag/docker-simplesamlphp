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
# System packages
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        gettext-base \
        libicu-dev \
        libzip-dev \
        unzip \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# PHP extensions required by SimpleSAMLphp 2.x
# ---------------------------------------------------------------------------
RUN docker-php-ext-install \
        intl \
        zip

# ---------------------------------------------------------------------------
# Apache modules
# ---------------------------------------------------------------------------
RUN a2enmod \
        headers \
        rewrite \
        ssl \
        socache_shmcb

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
# Copy configuration templates
# (envsubst fills in environment variables at container start)
# ---------------------------------------------------------------------------
COPY conf/simplesamlphp/config.php.template \
     /var/simplesamlphp/config/config.php.template
COPY conf/simplesamlphp/authsources.php.template \
     /var/simplesamlphp/config/authsources.php.template

# ---------------------------------------------------------------------------
# Copy Apache VirtualHost template
# ---------------------------------------------------------------------------
COPY conf/apache/simplesamlphp.conf.template \
     /etc/apache2/sites-available/simplesamlphp.conf.template

# ---------------------------------------------------------------------------
# Copy default IdP metadata (overridable via volume/ConfigMap mount)
# ---------------------------------------------------------------------------
COPY metadata/saml20-idp-remote.php \
     /var/simplesamlphp/metadata/saml20-idp-remote.php.default

# ---------------------------------------------------------------------------
# Copy and register the entrypoint script
# ---------------------------------------------------------------------------
COPY scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

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
ENV SIMPLESAMLPHP_TIMEZONE=UTC \
    SIMPLESAMLPHP_LOGGING_HANDLER=errorlog

# ---------------------------------------------------------------------------
# Volumes
#
#  /var/simplesamlphp/metadata  – IdP metadata (ConfigMap or bind-mount)
#  /var/simplesamlphp/cert      – SP signing key + cert (Secret or bind-mount)
#  /etc/ssl/certs               – Apache TLS certificate (Secret or bind-mount)
#  /etc/ssl/private             – Apache TLS private key (Secret or bind-mount)
# ---------------------------------------------------------------------------
VOLUME ["/var/simplesamlphp/metadata", "/var/simplesamlphp/cert", \
        "/etc/ssl/certs", "/etc/ssl/private"]

EXPOSE 80 443

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
