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

## Pre-built image

A multi-platform (`linux/amd64`, `linux/arm64`) image is published to the
**GitHub Container Registry** automatically on every push to `main`:

```
ghcr.io/atterdag/docker-simplesamlphp
```

### Tags

| Tag | Description |
|-----|-------------|
| `latest` | Most recent build from `main` |
| `ssp-<version>` | Pinned to a specific SimpleSAMLphp version (e.g. `ssp-2.5.0`) |
| `sha-<short>` | Pinned to a specific Git commit (e.g. `sha-a1b2c3d`) |

Use `ssp-<version>` or `sha-<short>` tags in production to avoid unexpected
updates.

### Using the pre-built image

**docker run / podman run:**

```bash
# Docker
docker run \
  -e DOMAIN_NAME=example.org \
  -e SERVER_NAME=simplesamlphp \
  -p 80:80 -p 443:443 \
  ghcr.io/atterdag/docker-simplesamlphp:latest

# Podman (rootless – ports ≥ 1024 only; see note below for 80/443)
podman run \
  -e DOMAIN_NAME=example.org \
  -e SERVER_NAME=simplesamlphp \
  -p 8080:80 -p 8443:443 \
  ghcr.io/atterdag/docker-simplesamlphp:latest
```

> **Podman rootless and privileged ports:** unprivileged users cannot bind to
> ports below 1024 by default.  Either use high ports (`8080`/`8443`) and
> reverse-proxy in front, or allow low ports system-wide:
> `sudo sysctl -w net.ipv4.ip_unprivileged_port_start=80`

**docker compose / podman compose** – replace the `build:` section in
`docker-compose.yml` with an `image:` reference to skip the local build step:

```yaml
services:
  simplesamlphp:
    image: ghcr.io/atterdag/docker-simplesamlphp:latest
    # remove or comment out the build: block
```

Then start with either:

```bash
docker compose up -d    # Docker
podman compose up -d    # Podman (≥ 4.7) or podman-compose
```

**Kubernetes** – use the image directly in the Deployment manifest:

```yaml
containers:
  - name: simplesamlphp
    image: ghcr.io/atterdag/docker-simplesamlphp:ssp-2.5.0
```

---

## Quick start

```bash
docker compose up --build    # Docker
podman compose up --build    # Podman (≥ 4.7) or podman-compose
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
| `SIMPLESAMLPHP_SP_ENTITY_ID` | `https://${FQDN}/simplesaml/module.php/saml/sp/metadata/default-sp` | SP entityID |
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
| `SIMPLESAMLPHP_LOG_DIR` | `/var/simplesamlphp/log` | Base directory for log files (used when `SIMPLESAMLPHP_LOGGING_HANDLER=file`) |
| `SIMPLESAMLPHP_STORE_TYPE` | `memcache` | Session store: `phpsession`, `memcache`, or `sql` |
| `MEMCACHE_SERVER_HOST` | `memcached` | Memcached hostname (used when `SIMPLESAMLPHP_STORE_TYPE=memcache`) |
| `MEMCACHE_SERVER_PORT` | `11211` | Memcached port |

### OpenID Connect (OIDC)

| Variable | Default | Description |
|---|---|---|
| `SIMPLESAMLPHP_OIDC_ISSUER` | *(empty)* | OIDC provider issuer URL (e.g. `https://accounts.google.com`). Set all three OIDC variables to enable the `oidc-sp` auth source. |
| `SIMPLESAMLPHP_OIDC_CLIENT_ID` | *(empty)* | Client ID registered with the OIDC provider |
| `SIMPLESAMLPHP_OIDC_CLIENT_SECRET` | *(empty)* | Client secret registered with the OIDC provider |

### Automated metadata management (metarefresh)

| Variable | Default | Description |
|---|---|---|
| `SIMPLESAMLPHP_CRON_SECRET` | *(auto-generated)* | Secret key that protects the cron HTTP trigger URL. Set a stable value in production (`openssl rand -hex 32`). |
| `SIMPLESAMLPHP_METAREFRESH_CRON_TAG` | `metarefresh` | Cron tag that links the metarefresh set to the cron module |
| `SIMPLESAMLPHP_METAREFRESH_METADATA_URL` | *(empty)* | URL of the remote federation / IdP aggregate metadata XML to fetch |
| `SIMPLESAMLPHP_METAREFRESH_OUTPUT_DIR` | `/var/simplesamlphp/metadata/metarefresh` | Directory inside the container where converted PHP metadata files are written |
| `SIMPLESAMLPHP_METAREFRESH_EXPIRE_AFTER` | `345600` | Seconds to keep stale metadata when the remote source is unavailable (default: 4 days) |

---

## Volume mounts

### Declared volumes and bind-mount overrides

The `Dockerfile` declares five volumes with the `VOLUME` instruction:

| Container path | Purpose |
|---|---|
| `/var/simplesamlphp/log` | SimpleSAMLphp and Apache log files |
| `/var/simplesamlphp/metadata` | IdP metadata (`saml20-idp-remote.php` and metarefresh output) |
| `/var/simplesamlphp/cert` | SP SAML signing key and certificate |
| `/etc/ssl/certs` | Apache TLS certificate(s) |
| `/etc/ssl/private` | Apache TLS private key(s) |

When a path is listed in `VOLUME`, Docker automatically creates an **anonymous
volume** for it if you do not provide your own mount.  Anonymous volumes are
managed by Docker, survive container restarts, but are lost when the container
is removed with `docker rm -v`.

To take control of a path – inspect its contents on the host, persist it
across container removals, or inject files into the container – replace the
anonymous volume with a **bind mount** pointing to a directory (or file) on
the host.  Bind mounts always win over anonymous volumes: Docker uses the
host path instead of the anonymous volume whenever you supply one explicitly.

#### docker run / podman run – bind-mount all volumes

```bash
# Docker
docker run \
  # Logs
  -v /host/logs:/var/simplesamlphp/log \
  # IdP metadata
  -v /host/metadata:/var/simplesamlphp/metadata \
  # SP SAML signing credentials
  -v /host/certs/sp:/var/simplesamlphp/cert:ro \
  # Apache TLS certificate
  -v /host/certs/ssl/certs:/etc/ssl/certs:ro \
  # Apache TLS private key
  -v /host/certs/ssl/private:/etc/ssl/private:ro \
  ghcr.io/atterdag/docker-simplesamlphp:latest

# Podman – identical flags; add :z or :Z for SELinux relabelling if needed
podman run \
  -v /host/logs:/var/simplesamlphp/log:z \
  -v /host/metadata:/var/simplesamlphp/metadata:z \
  -v /host/certs/sp:/var/simplesamlphp/cert:ro,z \
  -v /host/certs/ssl/certs:/etc/ssl/certs:ro,z \
  -v /host/certs/ssl/private:/etc/ssl/private:ro,z \
  ghcr.io/atterdag/docker-simplesamlphp:latest
```

You can override only the volumes you care about; any path not explicitly
mounted still gets an anonymous volume.

To bind-mount a **single file** (e.g. only the IdP metadata) rather than a
whole directory:

```bash
# Docker
docker run \
  -v /host/saml20-idp-remote.php:/var/simplesamlphp/metadata/saml20-idp-remote.php:ro \
  ghcr.io/atterdag/docker-simplesamlphp:latest

# Podman
podman run \
  -v /host/saml20-idp-remote.php:/var/simplesamlphp/metadata/saml20-idp-remote.php:ro,z \
  ghcr.io/atterdag/docker-simplesamlphp:latest
```

#### docker-compose.yml – bind-mount all volumes

Replace (or supplement) the named-volume entries in `docker-compose.yml` with
host paths:

```yaml
services:
  simplesamlphp:
    volumes:
      # Logs – host directory, writable so all replicas can append
      - /host/logs:/var/simplesamlphp/log

      # IdP metadata – whole directory (includes metarefresh output)
      - /host/metadata:/var/simplesamlphp/metadata

      # SP SAML signing credentials
      - /host/certs/sp:/var/simplesamlphp/cert:ro

      # Apache TLS certificate
      - /host/certs/ssl/certs:/etc/ssl/certs:ro

      # Apache TLS private key
      - /host/certs/ssl/private:/etc/ssl/private:ro
```

Relative paths (e.g. `./certs/sp`) are resolved relative to the directory
containing `docker-compose.yml`.

> **Permissions:** The entrypoint runs `chown -R www-data:www-data` on
> `/var/simplesamlphp/{config,metadata,cert,log}` and
> `/var/cache/simplesamlphp` at startup, so host directories used for those
> paths must be writable by the container's root process (UID 0) during the
> entrypoint phase.  Directories mounted `:ro` (cert, TLS) do not need to be
> writable.

---

### Log volume – persistent, multi-replica log storage

When `SIMPLESAMLPHP_LOGGING_HANDLER=file` the entrypoint writes both
SimpleSAMLphp and Apache logs under `SIMPLESAMLPHP_LOG_DIR` (default:
`/var/simplesamlphp/log`).  Each container creates its own sub-directory
named after `$HOSTNAME` (the Docker container short-ID or the Kubernetes pod
name), keeping every replica's logs separate while sharing a single volume.

**Docker Compose – named volume (single host):**

```yaml
services:
  simplesamlphp:
    environment:
      SIMPLESAMLPHP_LOGGING_HANDLER: file
      SIMPLESAMLPHP_LOG_DIR: /var/simplesamlphp/log
    volumes:
      - simplesamlphp-logs:/var/simplesamlphp/log

volumes:
  simplesamlphp-logs:
    driver: local
```

Logs are then accessible via:
```bash
docker compose exec simplesamlphp ls /var/simplesamlphp/log/
# <container-hostname>/
#   simplesamlphp.log
#   apache/
#     error.log
#     access.log
```

**Kubernetes – PersistentVolumeClaim (multi-replica):**

The `k8s/simplesamlphp.yaml` manifest includes a `PersistentVolumeClaim`
(`simplesamlphp-logs`) with `accessModes: [ReadWriteMany]`.  You must
supply a `storageClassName` that supports RWX for your cluster (e.g.
NFS, Azure Files, AWS EFS, GCP Filestore, or Rook/CephFS).

After deploying, each pod writes to its own sub-directory:
```
/var/simplesamlphp/log/
  simplesamlphp-abc12/    # pod 1 (HOSTNAME = pod name)
    simplesamlphp.log
    apache/
      error.log
      access.log
  simplesamlphp-xyz99/    # pod 2
    simplesamlphp.log
    apache/
      error.log
      access.log
```

> **Note:** When `SIMPLESAMLPHP_LOGGING_HANDLER` is `errorlog` (the image
> default), Apache logs continue to be written to the standard Apache log
> directory which the base image symlinks to `/dev/stdout` and `/dev/stderr`,
> so `docker logs` / `kubectl logs` continue to work as usual.  Only switch
> to `file` logging when you intend to persist logs on a volume.

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

## Docker Compose / Podman Compose deployment

The `docker-compose.yml` in the repository root starts SimpleSAMLphp together
with a Memcached sidecar for session storage.  All `docker compose` commands
below have a direct Podman equivalent – replace `docker compose` with
`podman compose` (Podman ≥ 4.7 has `compose` built-in; older versions need the
`podman-compose` package).

### Quick start

**1. Generate the SP SAML signing credentials**

These are the key/certificate used to sign SAML assertions – they are
**not** the Apache TLS certificate.

```bash
openssl req -newkey rsa:2048 -new -x509 -days 3652 -nodes \
  -out sp.crt -keyout sp.key \
  -subj "/CN=simplesamlphp.example.org"    # <CHANGE_ME> – use your actual FQDN

mkdir -p certs/sp
mv sp.key sp.crt certs/sp/
```

**2. Generate the Apache TLS certificate and key**

For local/dev use a self-signed certificate; for production supply a
certificate signed by a trusted CA (e.g. from Let's Encrypt).

```bash
# Self-signed – adjust the CN to match your FQDN
openssl req -newkey rsa:2048 -new -x509 -days 365 -nodes \
  -out simplesamlphp.example.org.crt \
  -keyout simplesamlphp.example.org.key \
  -subj "/CN=simplesamlphp.example.org"    # <CHANGE_ME>

mkdir -p certs/ssl/certs certs/ssl/private
mv simplesamlphp.example.org.crt certs/ssl/certs/
mv simplesamlphp.example.org.key certs/ssl/private/
```

**3. Configure environment variables**

Create a `.env` file next to `docker-compose.yml` and override at minimum
the domain, admin password, and a stable secret salt:

```bash
DOMAIN_NAME=example.org                        # <CHANGE_ME>
SERVER_NAME=simplesamlphp                      # <CHANGE_ME>
SIMPLESAMLPHP_ADMIN_PASSWORD=changeme          # <CHANGE_ME>
SIMPLESAMLPHP_SECRET_SALT=$(openssl rand -hex 32)
```

**4. Uncomment the certificate volume mounts in `docker-compose.yml`**

Edit `docker-compose.yml` and uncomment the volume entries for the SP
cert and Apache TLS cert so that the files created in steps 1 and 2 are
mounted into the container:

```yaml
volumes:
  - ./certs/sp:/var/simplesamlphp/cert:ro
  - ./certs/ssl/certs:/etc/ssl/certs:ro
  - ./certs/ssl/private:/etc/ssl/private:ro
```

**5. (Optional) Mount your IdP metadata**

If you have a `saml20-idp-remote.php` file, uncomment and adjust the
corresponding volume entry:

```yaml
volumes:
  - ./my-idp-metadata.php:/var/simplesamlphp/metadata/saml20-idp-remote.php:ro
```

**6. Start the stack**

```bash
docker compose up --build -d    # Docker
podman compose up --build -d    # Podman
```

**7. Check status**

```bash
# Docker
docker compose ps
docker compose logs -f simplesamlphp

# Podman
podman compose ps
podman compose logs -f simplesamlphp
```

SimpleSAMLphp will be available at `https://<FQDN>/simplesaml/`.

### Session store

`SIMPLESAMLPHP_STORE_TYPE` defaults to `memcache` in both the image and
`docker-compose.yml`. Sessions are stored in the Memcached container and
survive SimpleSAMLphp container restarts as long as Memcached is running.
Set it to `phpsession` to revert to single-node PHP sessions (no Memcached
required).

> **Important:** supply a fixed `SIMPLESAMLPHP_SECRET_SALT` value so that
> session tokens remain valid across SimpleSAMLphp container restarts.

### Injecting IdP metadata

Uncomment the IdP metadata volume in `docker-compose.yml` and point it at
your `saml20-idp-remote.php` file (see step 5 above).

---

## Kubernetes deployment

The `k8s/` directory contains ready-to-use manifests for deploying the full
stack (SimpleSAMLphp + Memcached) on Kubernetes.

### File overview

| File | Contents |
|------|----------|
| `k8s/namespace.yaml` | `simplesamlphp` Namespace |
| `k8s/memcached.yaml` | Memcached Deployment + ClusterIP Service |
| `k8s/simplesamlphp.yaml` | ConfigMap, Secrets, Deployment, and LoadBalancer Service |

### Quick start

**1. Choose an image**

Use the pre-built image from the GitHub Container Registry (see [Pre-built
image](#pre-built-image) above) or build and push your own:

```bash
# Option A – pre-built (no build step required)
IMAGE=ghcr.io/atterdag/docker-simplesamlphp:latest

# Option B – build and push your own
# Docker
docker build -t ghcr.io/<ORG>/docker-simplesamlphp:latest .
docker push ghcr.io/<ORG>/docker-simplesamlphp:latest
# Podman
podman build -t ghcr.io/<ORG>/docker-simplesamlphp:latest .
podman push ghcr.io/<ORG>/docker-simplesamlphp:latest

IMAGE=ghcr.io/<ORG>/docker-simplesamlphp:latest
```

**2. Create the SP SAML signing credentials**

```bash
openssl req -newkey rsa:2048 -new -x509 -days 3652 -nodes \
  -out sp.crt -keyout sp.key \
  -subj "/CN=simplesamlphp.example.org"    # <CHANGE_ME> – use your actual FQDN

kubectl apply -f k8s/namespace.yaml

kubectl create secret generic simplesamlphp-sp-cert \
  --namespace simplesamlphp \
  --from-file=sp.key=./sp.key \
  --from-file=sp.crt=./sp.crt
```

**3. Create the Apache TLS certificate and key**

```bash
kubectl create secret tls simplesamlphp-tls \
  --namespace simplesamlphp \
  --cert=./tls.crt \
  --key=./tls.key
```

**4. Edit `k8s/simplesamlphp.yaml`**

Replace every `<CHANGE_ME>` placeholder:

| Field | Description |
|-------|-------------|
| `DOMAIN_NAME` in ConfigMap | Your base domain |
| `SERVER_NAME` in ConfigMap | Short hostname (e.g. `simplesamlphp`) |
| `SIMPLESAMLPHP_ADMIN_PASSWORD` in Secret | A strong admin password |
| `SIMPLESAMLPHP_SECRET_SALT` in Secret | A stable random string (`openssl rand -hex 32`) |
| `image:` in Deployment | Your registry/image reference |

**5. Apply all manifests**

```bash
kubectl apply -f k8s/
```

**6. Check status**

```bash
kubectl -n simplesamlphp get pods,svc
```

SimpleSAMLphp will be available at the external IP assigned by the
LoadBalancer: `https://<EXTERNAL-IP>/simplesaml/`.

### Session store

`SIMPLESAMLPHP_STORE_TYPE` is set to `memcache` in
`k8s/simplesamlphp.yaml`.  Sessions are stored in the Memcached pod and
survive SimpleSAMLphp pod restarts as long as Memcached is running.  Set it
to `phpsession` to revert to single-node PHP sessions.

> **Important:** supply a fixed `SIMPLESAMLPHP_SECRET_SALT` value so that
> session tokens remain valid across SimpleSAMLphp pod restarts.

### Injecting IdP metadata

Uncomment the `simplesamlphp-idp-metadata` ConfigMap and the matching
`volumeMount` / `volume` entries in `k8s/simplesamlphp.yaml`, then populate
the ConfigMap with your IdP's `saml20-idp-remote.php` content.

---

## Automated metadata management (metarefresh)

The image includes the SimpleSAMLphp `cron` and `metarefresh` modules, which
allow federation or IdP aggregate metadata to be fetched and converted
automatically without rebuilding the image.

### How it works

1. The `metarefresh` module fetches a remote SAML 2.0 metadata XML aggregate
   and converts each entity into SimpleSAMLphp's PHP flatfile format, writing
   the files to `SIMPLESAMLPHP_METAREFRESH_OUTPUT_DIR`.
2. The `cron` module exposes an HTTP endpoint that triggers the refresh when
   called with the correct tag and secret:
   `https://<FQDN>/simplesaml/module.php/cron/run/<tag>/<secret>`
3. The refreshed metadata directory is registered as a second `flatfile`
   metadata source in `config.php`, so SimpleSAMLphp automatically picks up
   the converted files.

### Configuration

Set at least these two environment variables:

```bash
SIMPLESAMLPHP_CRON_SECRET=<openssl rand -hex 32>
SIMPLESAMLPHP_METAREFRESH_METADATA_URL=https://federation.example.org/metadata.xml
```

The cron tag defaults to `metarefresh` and the output directory to
`/var/simplesamlphp/metadata/metarefresh`.

### Triggering a refresh

**Docker Compose / Podman Compose – exec into the running container:**

```bash
docker compose exec simplesamlphp metarefresh.sh    # Docker
podman compose exec simplesamlphp metarefresh.sh    # Podman
```

**Docker / Podman – one-shot standalone container:**

```bash
# Docker
docker run --rm \
  -e SIMPLESAMLPHP_CRON_SECRET=<secret> \
  -e SIMPLESAMLPHP_METAREFRESH_METADATA_URL=https://federation.example.org/metadata.xml \
  -v ./metadata:/var/simplesamlphp/metadata \
  <image> metarefresh.sh

# Podman
podman run --rm \
  -e SIMPLESAMLPHP_CRON_SECRET=<secret> \
  -e SIMPLESAMLPHP_METAREFRESH_METADATA_URL=https://federation.example.org/metadata.xml \
  -v ./metadata:/var/simplesamlphp/metadata:z \
  <image> metarefresh.sh
```

The container runs the entrypoint (which generates all SimpleSAMLphp
configuration), starts Apache temporarily, calls the cron endpoint, and exits.

**Curl – against a running instance:**

```bash
curl "https://<FQDN>/simplesaml/module.php/cron/run/metarefresh/<secret>"
```

### Kubernetes CronJob

`k8s/metarefresh-cronjob.yaml` provides a ready-to-use CronJob manifest with
two approaches:

| Approach | How it works | When to use |
|----------|--------------|-------------|
| **A (default)** | A `curlimages/curl` pod calls the cron HTTP endpoint on the running SimpleSAMLphp Service | Simplest; requires the main Deployment to be running |
| **B (commented out)** | The SimpleSAMLphp image runs `metarefresh.sh` as a standalone job, writing output to a shared PVC | Fully self-contained; works even if the main Deployment is restarted |

**Quick start (Approach A):**

1. Add `SIMPLESAMLPHP_CRON_SECRET` to the `simplesamlphp-admin` Secret in
   `k8s/simplesamlphp.yaml` (see the `<CHANGE_ME>` placeholder).
2. Set `SIMPLESAMLPHP_METAREFRESH_METADATA_URL` in the ConfigMap.
3. Apply the manifests:

   ```bash
   kubectl apply -f k8s/simplesamlphp.yaml
   kubectl apply -f k8s/metarefresh-cronjob.yaml
   ```

4. Trigger a manual run to verify:

   ```bash
   kubectl -n simplesamlphp create job --from=cronjob/simplesamlphp-metarefresh metarefresh-test
   kubectl -n simplesamlphp logs -l app.kubernetes.io/component=metarefresh
   ```

> **Tip:** For refreshed metadata to survive SimpleSAMLphp pod restarts,
> mount a PersistentVolumeClaim at `/var/simplesamlphp/metadata` in the
> Deployment so that the `metarefresh` output directory persists.

### Validating metadata signatures

To verify the metadata aggregate signature, place the federation signing
certificate inside the container (e.g. via a volume mount or Secret) and
uncomment the `'certificates'` line in
`conf/simplesamlphp/module_metarefresh.php.template`:

```php
'certificates' => ['/var/simplesamlphp/cert/federation-signing.pem'],
```

---

## Building

```bash
# Default version (2.5.0)
docker build -t simplesamlphp .    # Docker
podman build -t simplesamlphp .    # Podman

# Specific SimpleSAMLphp version
docker build --build-arg SIMPLESAMLPHP_VERSION=2.5.0 -t simplesamlphp .
podman build --build-arg SIMPLESAMLPHP_VERSION=2.5.0 -t simplesamlphp .
```

### Custom artifact registry / corporate proxy

All external downloads performed during the image build can be redirected to
an artifact management solution such as **JFrog Artifactory**, **Sonatype
Nexus**, or any other Docker / generic / Composer proxy repository.

#### Build ARGs

| Argument | Default | Description |
|---|---|---|
| `COMPOSER_IMAGE` | `composer:2` | Composer builder image (Docker Hub) |
| `PHP_IMAGE` | `php:8.4-apache` | PHP + Apache base image (Docker Hub) |
| `SIMPLESAMLPHP_TARBALL_URL` | *(GitHub Releases)* | Full URL of the SimpleSAMLphp release tarball. Defaults to `https://github.com/simplesamlphp/simplesamlphp/releases/download/v<VERSION>/simplesamlphp-<VERSION>-full.tar.gz` |
| `COMPOSER_PACKAGIST_URL` | *(packagist.org)* | Composer repository URL to use instead of `packagist.org`. Set to your Artifactory Composer remote-repository URL to cache PHP packages locally. |

#### Example – Artifactory

```bash
# Docker
docker build \
  --build-arg COMPOSER_IMAGE=artifactory.example.com/docker/composer:2 \
  --build-arg PHP_IMAGE=artifactory.example.com/docker/php:8.4-apache \
  --build-arg SIMPLESAMLPHP_TARBALL_URL=https://artifactory.example.com/generic-remote/simplesamlphp/simplesamlphp-2.5.0-full.tar.gz \
  --build-arg COMPOSER_PACKAGIST_URL=https://artifactory.example.com/api/composer/packagist \
  -t simplesamlphp .

# Podman (identical flags)
podman build \
  --build-arg COMPOSER_IMAGE=artifactory.example.com/docker/composer:2 \
  --build-arg PHP_IMAGE=artifactory.example.com/docker/php:8.4-apache \
  --build-arg SIMPLESAMLPHP_TARBALL_URL=https://artifactory.example.com/generic-remote/simplesamlphp/simplesamlphp-2.5.0-full.tar.gz \
  --build-arg COMPOSER_PACKAGIST_URL=https://artifactory.example.com/api/composer/packagist \
  -t simplesamlphp .
```

When using **Docker Compose**, set the same variables in a `.env` file next
to `docker-compose.yml`:

```bash
COMPOSER_IMAGE=artifactory.example.com/docker/composer:2
PHP_IMAGE=artifactory.example.com/docker/php:8.4-apache
SIMPLESAMLPHP_TARBALL_URL=https://artifactory.example.com/generic-remote/simplesamlphp/simplesamlphp-2.5.0-full.tar.gz
COMPOSER_PACKAGIST_URL=https://artifactory.example.com/api/composer/packagist
MEMCACHED_IMAGE=artifactory.example.com/docker/memcached:alpine
```

Then run:

```bash
docker compose up --build    # Docker
podman compose up --build    # Podman
```

> **Kubernetes:** The `k8s/memcached.yaml` and `k8s/metarefresh-cronjob.yaml`
> manifests contain inline comments indicating where to replace the image
> references with your corporate registry equivalents.

---

## Directory layout

```
.
├── Dockerfile
├── docker-compose.yml
├── k8s/
│   ├── namespace.yaml               # simplesamlphp Namespace
│   ├── memcached.yaml               # Memcached Deployment + Service
│   ├── simplesamlphp.yaml           # ConfigMap, Secrets, Deployment, Service
│   └── metarefresh-cronjob.yaml     # CronJob for automated metadata refresh
├── conf/
│   ├── apache/
│   │   └── simplesamlphp.conf.template   # Apache VirtualHost template
│   └── simplesamlphp/
│       ├── config.php.template           # SimpleSAMLphp main config
│       ├── authsources.php.template      # SP / auth source config
│       ├── module_cron.php.template      # Cron module config
│       └── module_metarefresh.php.template  # MetaRefresh module config
├── metadata/
│   └── saml20-idp-remote.php             # Default (empty) IdP metadata
└── scripts/
    ├── docker-entrypoint.sh              # Entrypoint: resolves env vars,
    │                                     # runs envsubst, starts Apache
    └── metarefresh.sh                    # Ad-hoc / standalone metadata
                                          # refresh trigger script
```
