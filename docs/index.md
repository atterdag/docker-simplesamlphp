# docker-simplesamlphp – documentation

This directory contains step-by-step guides for deploying and configuring
`docker-simplesamlphp`.

## Guides

| Guide | Description |
|-------|-------------|
| [SAML 2.0 SP setup](saml-sp.md) | Configure SimpleSAMLphp as a SAML 2.0 Service Provider |
| [OIDC Relying Party setup](oidc.md) | Authenticate users via an OpenID Connect provider |
| [Automated metadata (metarefresh)](metarefresh.md) | Fetch and refresh federation / IdP metadata automatically |
| [Kubernetes deployment](kubernetes.md) | Deploy the full stack on Kubernetes |

## Environment variables at a glance

All runtime behaviour is controlled through environment variables that the
`docker-entrypoint.sh` script evaluates at container start.

| Variable | Default | Purpose |
|----------|---------|---------|
| `DOMAIN_NAME` | `se.lemche.net` | DNS domain used to derive the FQDN |
| `SERVER_NAME` | `simplesamlphp` | Short hostname; `FQDN = SERVER_NAME.DOMAIN_NAME` |
| `SIMPLESAMLPHP_ADMIN_PASSWORD` | `admin` | Admin UI password – **change in production** |
| `SIMPLESAMLPHP_SECRET_SALT` | *(auto-generated)* | Secret salt for token generation |
| `SIMPLESAMLPHP_SP_PRIVATEKEY` | `sp.key` | SP signing key filename (relative to `/var/simplesamlphp/cert/`) |
| `SIMPLESAMLPHP_SP_CERTIFICATE` | `sp.crt` | SP certificate filename |
| `SIMPLESAMLPHP_SP_WANT_ASSERTIONS_SIGNED` | `true` | Require signed assertions from the IdP |
| `SIMPLESAMLPHP_SP_WANT_MESSAGE_SIGNED` | `true` | Require signed SAML Response from the IdP |
| `SIMPLESAMLPHP_STORE_TYPE` | `memcache` | Session store: `phpsession`, `memcache`, or `sql` |
| `MEMCACHE_SERVER_HOST` | `memcached` | Memcached hostname |
| `MEMCACHE_SERVER_PORT` | `11211` | Memcached port |
| `SIMPLESAMLPHP_OIDC_ISSUER` | *(empty)* | OIDC provider issuer URL |
| `SIMPLESAMLPHP_OIDC_CLIENT_ID` | *(empty)* | OIDC client ID |
| `SIMPLESAMLPHP_OIDC_CLIENT_SECRET` | *(empty)* | OIDC client secret |
| `SIMPLESAMLPHP_METAREFRESH_METADATA_URL` | *(empty)* | URL of the federation/IdP metadata XML |
| `SIMPLESAMLPHP_CRON_SECRET` | *(auto-generated)* | Secret key for the cron HTTP endpoint |
