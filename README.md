# docker-simplesamlphp

Docker image that runs [SimpleSAMLphp](https://simplesamlphp.org/) as a
SAML 2.0 Service Provider on Apache with PHP.

---

## Features

* Apache `Define` directives are populated from shell/environment variables
  so that network names and TLS paths can be overridden without rebuilding
  the image.
* SimpleSAMLphp SP `entityID`, `privatekey`, `certificate`,
  `WantAssertionsSigned` and `WantSignedResponse` are fully configurable
  via environment variables (default: both signing requirements **enabled**).
* IdP metadata (`saml20-idp-remote.php`) can be injected at runtime via a
  Docker bind-mount or a Kubernetes **ConfigMap**.
* TLS certificates and keys can be injected at runtime via Docker
  bind-mounts or Kubernetes **Secrets**.

---

## Quick start

```bash
docker compose up --build
```

The container exposes port **80** (redirects to HTTPS) and **443**.

SimpleSAMLphp is available at `https://<FQDN>/simplesaml/`.

---

## Environment variables

### Apache / network

| Variable               | Default                              | Description |
|------------------------|--------------------------------------|-------------|
| `DOMAIN_NAME`          | `se.lemche.net`                      | Base domain |
| `SERVER_NAME`          | `simplesamlphp`                      | Short hostname |
| `SERVER_ALIAS`         | `${SERVER_NAME}`                     | Additional `ServerAlias` |
| `FQDN`                 | `${SERVER_NAME}.${DOMAIN_NAME}`      | Fully-qualified hostname |
| `WEBMASTER`            | `webmaster@${DOMAIN_NAME}`           | `ServerAdmin` address |
| `SSL_CERTIFICATE_FILE` | `/etc/ssl/certs/${FQDN}.crt`         | Path to Apache TLS certificate |
| `SSL_PRIVATE_KEY_FILE` | `/etc/ssl/private/${FQDN}.key`       | Path to Apache TLS private key |

These become Apache `Define` directives in the generated VirtualHost
configuration, so you can reference them with `${VARIABLE}` anywhere in
custom Apache snippets.

### SimpleSAMLphp

| Variable | Default | Description |
|---|---|---|
| `SIMPLESAMLPHP_BASE_URL_PATH` | `https://${FQDN}/simplesaml/` | Base URL path |
| `SIMPLESAMLPHP_SP_ENTITY_ID` | `https://${FQDN}/simplesaml/…` | SP entityID |
| `SIMPLESAMLPHP_SP_PRIVATEKEY` | `sp.key` | SP private key filename in `certdir` |
| `SIMPLESAMLPHP_SP_CERTIFICATE` | `sp.crt` | SP certificate filename in `certdir` |
| `SIMPLESAMLPHP_SP_WANT_ASSERTIONS_SIGNED` | `true` | Require signed assertions |
| `SIMPLESAMLPHP_SP_WANT_MESSAGE_SIGNED` | `true` | Require signed response messages |
| `SIMPLESAMLPHP_ADMIN_PASSWORD` | `admin` | Admin UI password (**change this!**) |
| `SIMPLESAMLPHP_SECRET_SALT` | *(auto-generated)* | Random salt for token hashes |
| `SIMPLESAMLPHP_TECHNICAL_CONTACT_NAME` | `Administrator` | Contact name in metadata |
| `SIMPLESAMLPHP_TECHNICAL_CONTACT_EMAIL` | `webmaster@${DOMAIN_NAME}` | Contact e-mail |
| `SIMPLESAMLPHP_TIMEZONE` | `UTC` | PHP timezone |
| `SIMPLESAMLPHP_LOGGING_HANDLER` | `errorlog` | `errorlog`, `syslog`, or `file` |

---

## Volume mounts

### IdP metadata – `saml20-idp-remote.php`

The IdP metadata file can be provided from outside the container.

**Docker bind-mount (docker-compose.yml):**

```yaml
volumes:
  - ./my-idp-metadata.php:/var/simplesamlphp/metadata/saml20-idp-remote.php:ro
```

**Kubernetes ConfigMap:**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: simplesamlphp-idp-metadata
data:
  saml20-idp-remote.php: |
    <?php
    $metadata['https://idp.example.org/'] = [
        'SingleSignOnService' => 'https://idp.example.org/saml/SSO',
        'certData' => '...base64...',
    ];
---
# In the Pod spec:
volumes:
  - name: idp-metadata
    configMap:
      name: simplesamlphp-idp-metadata
containers:
  - name: simplesamlphp
    volumeMounts:
      - name: idp-metadata
        mountPath: /var/simplesamlphp/metadata/saml20-idp-remote.php
        subPath: saml20-idp-remote.php
        readOnly: true
```

### SP signing key and certificate

These are the SAML signing/encryption credentials (not the Apache TLS
certificate). Place files named by `SIMPLESAMLPHP_SP_PRIVATEKEY` and
`SIMPLESAMLPHP_SP_CERTIFICATE` (defaults: `sp.key` / `sp.crt`) in the
mounted directory.

**Docker bind-mount:**

```yaml
volumes:
  - ./certs/sp:/var/simplesamlphp/cert:ro
```

**Kubernetes Secret:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: simplesamlphp-sp-cert
type: Opaque
data:
  sp.key: <base64-encoded-private-key>
  sp.crt: <base64-encoded-certificate>
---
volumes:
  - name: sp-cert
    secret:
      secretName: simplesamlphp-sp-cert
containers:
  - name: simplesamlphp
    volumeMounts:
      - name: sp-cert
        mountPath: /var/simplesamlphp/cert
        readOnly: true
```

### Apache TLS certificate and key

**Docker bind-mounts:**

```yaml
volumes:
  - ./certs/ssl/certs:/etc/ssl/certs:ro
  - ./certs/ssl/private:/etc/ssl/private:ro
```

Or override `SSL_CERTIFICATE_FILE` / `SSL_PRIVATE_KEY_FILE` to point to
any path inside the container and mount a Kubernetes TLS Secret there:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: simplesamlphp-tls
type: kubernetes.io/tls
data:
  tls.crt: <base64>
  tls.key: <base64>
---
volumes:
  - name: tls
    secret:
      secretName: simplesamlphp-tls
containers:
  - name: simplesamlphp
    env:
      - name: SSL_CERTIFICATE_FILE
        value: /etc/ssl/tls.crt
      - name: SSL_PRIVATE_KEY_FILE
        value: /etc/ssl/tls.key
    volumeMounts:
      - name: tls
        mountPath: /etc/ssl
        readOnly: true
```

---

## Building

```bash
# Default version (2.5.0)
docker build -t simplesamlphp .

# Specific SimpleSAMLphp version
docker build --build-arg SIMPLESAMLPHP_VERSION=2.5.0 -t simplesamlphp .
```

---

## Directory layout

```
.
├── Dockerfile
├── docker-compose.yml
├── conf/
│   ├── apache/
│   │   └── simplesamlphp.conf.template   # Apache VirtualHost template
│   └── simplesamlphp/
│       ├── config.php.template           # SimpleSAMLphp main config
│       └── authsources.php.template      # SP / auth source config
├── metadata/
│   └── saml20-idp-remote.php             # Default (empty) IdP metadata
└── scripts/
    └── docker-entrypoint.sh              # Entrypoint: resolves env vars,
                                          # runs envsubst, starts Apache
```
