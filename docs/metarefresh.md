# Automated metadata management (metarefresh)

The image includes the SimpleSAMLphp **cron** and **metarefresh** modules.
Together they periodically fetch a remote SAML 2.0 metadata XML aggregate
(e.g. a federation or a single IdP) and convert it into PHP flatfiles that
SimpleSAMLphp reads automatically — without rebuilding the image or restarting
the container.

---

## How it works

1. The **cron** module exposes an HTTP endpoint that, when called with the
   correct secret key, runs all scheduled tasks for a given cron tag.
2. The **metarefresh** module registers a task against the `metarefresh` cron
   tag.  When triggered it downloads the metadata XML from
   `SIMPLESAMLPHP_METAREFRESH_METADATA_URL`, validates it (optionally), and
   writes converted PHP files to `SIMPLESAMLPHP_METAREFRESH_OUTPUT_DIR`.
3. The `config.php` `metadata.sources` array includes the output directory,
   so SimpleSAMLphp picks up the refreshed metadata on the next request.

---

## Prerequisites

* A URL that serves a SAML 2.0 metadata XML aggregate — either a federation
  aggregate (e.g. eduGAIN, SWAMID, InCommon) or a single-IdP metadata URL.
* The container must be able to reach that URL over HTTPS.

---

## Step 1 – Set environment variables

### Required

| Variable | Description |
|----------|-------------|
| `SIMPLESAMLPHP_METAREFRESH_METADATA_URL` | Full URL of the metadata XML aggregate |
| `SIMPLESAMLPHP_CRON_SECRET` | Secret key for the cron endpoint (generate with `openssl rand -hex 32`) |

### Optional

| Variable | Default | Description |
|----------|---------|-------------|
| `SIMPLESAMLPHP_METAREFRESH_CRON_TAG` | `metarefresh` | Cron tag name |
| `SIMPLESAMLPHP_METAREFRESH_OUTPUT_DIR` | `/var/simplesamlphp/metadata/metarefresh` | Directory where converted PHP files are written |
| `SIMPLESAMLPHP_METAREFRESH_EXPIRE_AFTER` | `345600` (4 days) | Seconds before stale cached metadata is discarded |

---

## Step 2 – Configure Docker Compose

Add to the `environment:` block in `docker-compose.yml`:

```yaml
SIMPLESAMLPHP_CRON_SECRET:              "<output-of-openssl-rand-hex-32>"
SIMPLESAMLPHP_METAREFRESH_METADATA_URL: "https://federation.example.org/metadata.xml"
```

If you want the converted metadata to persist across container restarts,
mount a volume for the metadata directory:

```yaml
volumes:
  - simplesamlphp-metadata:/var/simplesamlphp/metadata

volumes:
  simplesamlphp-metadata:
    driver: local
```

---

## Step 3 – Trigger the first metadata refresh

### Option A – exec into the running container

```bash
docker compose exec simplesamlphp metarefresh.sh
```

### Option B – one-shot standalone container

```bash
docker run --rm \
  -e SIMPLESAMLPHP_CRON_SECRET="<your-cron-secret>" \
  -e SIMPLESAMLPHP_METAREFRESH_METADATA_URL="https://federation.example.org/metadata.xml" \
  -v ./metadata:/var/simplesamlphp/metadata \
  ghcr.io/atterdag/docker-simplesamlphp:latest \
  metarefresh.sh
```

### Option C – call the cron HTTP endpoint directly

```bash
curl -s "https://simplesamlphp.example.org/simplesaml/module.php/cron/run/metarefresh/<CRON_SECRET>"
```

---

## Step 4 – Schedule recurring refreshes

### Kubernetes CronJob

The repository ships a ready-made CronJob at `k8s/metarefresh-cronjob.yaml`.
Apply it after the main stack is running:

```bash
kubectl apply -f k8s/metarefresh-cronjob.yaml
```

The CronJob runs `metarefresh.sh` inside a temporary pod every hour by
default.  Update the `schedule:` field to change the frequency.

### Host cron (Docker Compose)

Add a cron entry on the Docker host:

```cron
0 * * * * docker exec simplesamlphp_simplesamlphp_1 metarefresh.sh >> /var/log/metarefresh.log 2>&1
```

Or call the HTTP endpoint from a host cron job:

```cron
0 * * * * curl -s "https://simplesamlphp.example.org/simplesaml/module.php/cron/run/metarefresh/<CRON_SECRET>" >> /var/log/metarefresh.log 2>&1
```

---

## Step 5 – Validate the metadata signature (optional but recommended)

If your federation publishes a signing certificate, configure metarefresh to
verify it:

1. Download the federation signing certificate in PEM format and place it at
   `/var/simplesamlphp/cert/federation-signing.pem` inside the container (via
   a volume bind-mount or Kubernetes Secret).

2. Edit `conf/simplesamlphp/module_metarefresh.php.template` and uncomment:

   ```php
   'certificates' => ['/var/simplesamlphp/cert/federation-signing.pem'],
   ```

3. Rebuild the image or mount a custom template file.

---

## Verify the result

After a successful refresh the output directory contains converted PHP files
such as `saml20-idp-remote.php`.  You can confirm this by:

```bash
docker compose exec simplesamlphp ls /var/simplesamlphp/metadata/metarefresh/
```

SimpleSAMLphp's admin UI also lists all loaded IdPs under
**Federation** → **SAML 2.0 IdP remote**.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `[metarefresh] ERROR: SIMPLESAMLPHP_CRON_SECRET is not set` | Secret not passed to the `metarefresh.sh` container | Set `SIMPLESAMLPHP_CRON_SECRET` in the environment |
| HTTP 403 from cron endpoint | Wrong secret | Check `SIMPLESAMLPHP_CRON_SECRET` matches in both the container and the caller |
| Empty output directory after refresh | Wrong metadata URL or network error | Run `metarefresh.sh` manually and check the output for curl errors |
| `SSL certificate problem` when fetching metadata | Self-signed or untrusted CA on the metadata server | Mount the CA certificate into the container and configure curl / SimpleSAMLphp to trust it |
| Stale metadata warning | `SIMPLESAMLPHP_METAREFRESH_EXPIRE_AFTER` too short or refresh not running | Increase expire-after or ensure the cron job is scheduled |
