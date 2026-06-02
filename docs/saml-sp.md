# SAML 2.0 Service Provider setup

This guide walks you through configuring `docker-simplesamlphp` as a SAML 2.0
Service Provider (SP) that federates with an external Identity Provider (IdP).

---

## Prerequisites

* Docker (≥ 24) or Podman (≥ 4.7) installed
* A SAML 2.0 Identity Provider you control or have admin access to
* A DNS name that resolves to your host (e.g. `simplesamlphp.example.org`)
* TLS certificate and key for the Apache VirtualHost
* SP signing key and certificate for SAML message signing/encryption

---

## Step 1 – Generate SP signing credentials

SimpleSAMLphp uses a separate key pair to **sign AuthnRequests** and
**decrypt encrypted assertions**.  This is distinct from the Apache TLS
certificate.

```bash
openssl req -newkey rsa:2048 -new -x509 -days 3652 -nodes \
  -out sp.crt -keyout sp.key \
  -subj "/CN=simplesamlphp.example.org"
```

Keep both files safe – you will reference them in the next step.

---

## Step 2 – Obtain (or self-sign) a TLS certificate

Apache needs a TLS certificate for HTTPS.  For testing, generate a self-signed
one:

```bash
openssl req -newkey rsa:2048 -new -x509 -days 365 -nodes \
  -out simplesamlphp.example.org.crt \
  -keyout simplesamlphp.example.org.key \
  -subj "/CN=simplesamlphp.example.org"
```

For production, use a certificate from a public CA (e.g. Let's Encrypt).

---

## Step 3 – Obtain IdP metadata

Ask your IdP operator for the SAML 2.0 metadata XML, or download it from the
IdP's well-known URL (e.g. `https://idp.example.org/saml/metadata`).

Convert the XML to SimpleSAMLphp PHP format.  The easiest way is to let
SimpleSAMLphp's admin UI do it:

1. Start the container (Step 4).
2. Browse to `https://<FQDN>/simplesaml/` → **XML to SimpleSAMLphp metadata
   converter**.
3. Paste the IdP metadata XML and click **Parse**.
4. Copy the generated PHP array into `saml20-idp-remote.php`:

```php
<?php
$metadata['https://idp.example.org/'] = [
    'name' => ['en' => 'Example IdP'],
    'SingleSignOnService' => 'https://idp.example.org/saml/SSO',
    'SingleLogoutService'  => 'https://idp.example.org/saml/SLO',
    'certData' => '<base64-encoded-certificate-without-PEM-headers>',
];
```

Alternatively, if your federation publishes an aggregate metadata XML you can
use the [metarefresh module](metarefresh.md) to fetch it automatically.

---

## Step 4 – Start the container

### Docker Compose (recommended)

Create a directory layout:

```
my-simplesamlphp/
├── certs/
│   ├── sp/
│   │   ├── sp.key
│   │   └── sp.crt
│   └── ssl/
│       ├── certs/
│       │   └── simplesamlphp.example.org.crt
│       └── private/
│           └── simplesamlphp.example.org.key
├── metadata/
│   └── saml20-idp-remote.php
└── docker-compose.yml
```

`docker-compose.yml`:

```yaml
services:
  memcached:
    image: memcached:alpine
    restart: unless-stopped

  simplesamlphp:
    image: ghcr.io/atterdag/docker-simplesamlphp:latest
    depends_on:
      - memcached
    environment:
      DOMAIN_NAME:  example.org
      SERVER_NAME:  simplesamlphp
      SIMPLESAMLPHP_ADMIN_PASSWORD: "<strong-password>"
      SIMPLESAMLPHP_SECRET_SALT:    "<output-of-openssl-rand-hex-32>"
      SIMPLESAMLPHP_STORE_TYPE:     memcache
      MEMCACHE_SERVER_HOST:         memcached
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./certs/sp:/var/simplesamlphp/cert:ro
      - ./certs/ssl/certs:/etc/ssl/certs:ro
      - ./certs/ssl/private:/etc/ssl/private:ro
      - ./metadata/saml20-idp-remote.php:/var/simplesamlphp/metadata/saml20-idp-remote.php:ro
```

Start the stack:

```bash
docker compose up -d
```

### docker run (single node, phpsession store)

```bash
docker run -d \
  -e DOMAIN_NAME=example.org \
  -e SERVER_NAME=simplesamlphp \
  -e SIMPLESAMLPHP_ADMIN_PASSWORD="<strong-password>" \
  -e SIMPLESAMLPHP_STORE_TYPE=phpsession \
  -v ./certs/sp:/var/simplesamlphp/cert:ro \
  -v ./certs/ssl/certs:/etc/ssl/certs:ro \
  -v ./certs/ssl/private:/etc/ssl/private:ro \
  -v ./metadata/saml20-idp-remote.php:/var/simplesamlphp/metadata/saml20-idp-remote.php:ro \
  -p 80:80 -p 443:443 \
  ghcr.io/atterdag/docker-simplesamlphp:latest
```

---

## Step 5 – Register the SP with the IdP

The IdP needs to know about your SP.  Provide the IdP operator with your SP
metadata, available at:

```
https://simplesamlphp.example.org/simplesaml/module.php/saml/sp/metadata/default-sp
```

Key values the IdP will need:

| Field | Value |
|-------|-------|
| **entityID** | `https://simplesamlphp.example.org/simplesaml/module.php/saml/sp/metadata/default-sp` |
| **Assertion Consumer Service (ACS) URL** | `https://simplesamlphp.example.org/simplesaml/module.php/saml/sp/saml2-acs.php/default-sp` |
| **Single Logout Service (SLO) URL** | `https://simplesamlphp.example.org/simplesaml/module.php/saml/sp/saml2-logout.php/default-sp` |
| **SP certificate** | Contents of `sp.crt` |

> **Custom entityID:** override `SIMPLESAMLPHP_SP_ENTITY_ID` to use a
> different entityID URI instead of the metadata URL default.

---

## Step 6 – Test the authentication flow

1. Browse to `https://simplesamlphp.example.org/simplesaml/`.
2. Click **Authentication** → **Test configured authentication sources**.
3. Select **default-sp** and click **Login**.
4. You will be redirected to the IdP login page.
5. After successful login you are redirected back; the page shows the SAML
   attributes released by the IdP.

---

## Key environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SIMPLESAMLPHP_SP_ENTITY_ID` | `https://<FQDN>/simplesaml/module.php/saml/sp/metadata/default-sp` | SP entityID URI |
| `SIMPLESAMLPHP_SP_PRIVATEKEY` | `sp.key` | Key filename relative to `/var/simplesamlphp/cert/` |
| `SIMPLESAMLPHP_SP_CERTIFICATE` | `sp.crt` | Certificate filename |
| `SIMPLESAMLPHP_SP_WANT_ASSERTIONS_SIGNED` | `true` | Reject unsigned assertions |
| `SIMPLESAMLPHP_SP_WANT_MESSAGE_SIGNED` | `true` | Reject unsigned SAML Responses |

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `Certificate verify failed` in SimpleSAMLphp logs | Self-signed IdP cert or missing CA bundle | Add the IdP CA to the container's trust store, or set `'saml.disable_ssl_verification' => true` in `config.php` (development only) |
| `No metadata found for entity` | IdP entityID in `saml20-idp-remote.php` does not match what the IdP advertises | Check the IdP metadata XML and update the PHP key |
| Redirect loop after login | ACS URL misconfigured at the IdP | Verify the ACS URL registered with the IdP matches the URL above |
| `Signature validation failed` | SP certificate at the IdP is stale | Re-register the SP with the current `sp.crt` |
