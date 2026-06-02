# Kubernetes deployment

This guide describes how to deploy the full `docker-simplesamlphp` stack on
Kubernetes using the manifests in the `k8s/` directory.

---

## Architecture

```
┌─────────────────────────────────────────┐
│ Namespace: simplesamlphp                │
│                                         │
│  Deployment: simplesamlphp ─────────────┼── Service (LoadBalancer :80/:443)
│    ├── ConfigMap (env vars)             │
│    ├── Secret (admin creds + salt)      │
│    ├── Secret (SP signing key/cert)     │
│    ├── Secret (Apache TLS cert/key)     │
│    └── PVC (logs)                       │
│                                         │
│  Deployment: memcached                  │
│    └── Service (ClusterIP :11211)       │
│                                         │
│  CronJob: metarefresh (optional)        │
└─────────────────────────────────────────┘
```

---

## Prerequisites

* `kubectl` configured against your cluster
* Container image pushed to a registry your cluster can pull from
* A StorageClass that supports **ReadWriteMany** (required for multi-replica
  log volumes; use ReadWriteOnce for single-replica deployments)

---

## Step 1 – Build and push the image

```bash
docker build -t ghcr.io/<ORG>/docker-simplesamlphp:2.5.0 .
docker push ghcr.io/<ORG>/docker-simplesamlphp:2.5.0
```

Update the `image:` field in `k8s/simplesamlphp.yaml` to match.

---

## Step 2 – Create the namespace

```bash
kubectl apply -f k8s/namespace.yaml
```

---

## Step 3 – Generate secrets

### Admin credentials and secret salt

```bash
# Generate values
ADMIN_PASSWORD=$(openssl rand -base64 24)
SECRET_SALT=$(openssl rand -hex 32)
CRON_SECRET=$(openssl rand -hex 32)

kubectl create secret generic simplesamlphp-admin \
  --namespace simplesamlphp \
  --from-literal=SIMPLESAMLPHP_ADMIN_PASSWORD="${ADMIN_PASSWORD}" \
  --from-literal=SIMPLESAMLPHP_SECRET_SALT="${SECRET_SALT}" \
  --from-literal=SIMPLESAMLPHP_CRON_SECRET="${CRON_SECRET}"
```

> **Tip:** store `ADMIN_PASSWORD` and `CRON_SECRET` somewhere safe; you will
> need them later.

### SP SAML signing credentials

```bash
openssl req -newkey rsa:2048 -new -x509 -days 3652 -nodes \
  -out sp.crt -keyout sp.key \
  -subj "/CN=simplesamlphp.example.org"

kubectl create secret generic simplesamlphp-sp-cert \
  --namespace simplesamlphp \
  --from-file=sp.key=./sp.key \
  --from-file=sp.crt=./sp.crt
```

### Apache TLS certificate

```bash
# Option A – Let's Encrypt / cert-manager (recommended for production):
# Install cert-manager, create a Certificate resource, and reference the
# resulting Secret in the Deployment volumeMount (see TLS termination note).

# Option B – Existing PEM files:
kubectl create secret tls simplesamlphp-tls \
  --namespace simplesamlphp \
  --cert=./tls.crt \
  --key=./tls.key
```

---

## Step 4 – Edit the ConfigMap

Open `k8s/simplesamlphp.yaml` and replace every `<CHANGE_ME>` placeholder:

| Key | What to set |
|-----|-------------|
| `DOMAIN_NAME` | Your DNS domain (e.g. `example.org`) |
| `SERVER_NAME` | Short hostname (e.g. `simplesamlphp`) |
| `SIMPLESAMLPHP_TECHNICAL_CONTACT_NAME` | Your name or team name |
| `SIMPLESAMLPHP_TECHNICAL_CONTACT_EMAIL` | Contact e-mail address |
| `SIMPLESAMLPHP_METAREFRESH_METADATA_URL` | Federation/IdP metadata URL (leave empty if unused) |

---

## Step 5 – Apply all manifests

```bash
kubectl apply -f k8s/
```

This creates (in order):

1. `namespace.yaml` – `simplesamlphp` namespace
2. `memcached.yaml` – Memcached Deployment + ClusterIP Service
3. `simplesamlphp.yaml` – ConfigMap, Secrets stubs, PVC, Deployment, Service
4. `metarefresh-cronjob.yaml` – optional CronJob for metadata refresh

---

## Step 6 – Verify the deployment

```bash
kubectl -n simplesamlphp get pods
kubectl -n simplesamlphp get svc
```

Wait until the `simplesamlphp` pod shows `Running` and the `READY` column
shows `1/1`.

Get the external IP or hostname assigned by the LoadBalancer:

```bash
kubectl -n simplesamlphp get svc simplesamlphp
```

Browse to `https://<EXTERNAL-IP>/simplesaml/` and log in with the admin
password.

---

## Step 7 – Inject IdP metadata (SAML)

### Option A – ConfigMap (static metadata)

Uncomment the `simplesamlphp-idp-metadata` ConfigMap and the corresponding
`volumeMount` / `volume` entries in `k8s/simplesamlphp.yaml`, then populate
the PHP array:

```yaml
# k8s/simplesamlphp.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: simplesamlphp-idp-metadata
  namespace: simplesamlphp
data:
  saml20-idp-remote.php: |
    <?php
    $metadata['https://idp.example.org/'] = [
        'SingleSignOnService' => 'https://idp.example.org/saml/SSO',
        'certData' => '<base64-certificate>',
    ];
```

### Option B – metarefresh CronJob (dynamic metadata)

Set `SIMPLESAMLPHP_METAREFRESH_METADATA_URL` in the ConfigMap and apply
`k8s/metarefresh-cronjob.yaml`.  See [metarefresh guide](metarefresh.md) for
details.

---

## Step 8 – Enable OIDC (optional)

Add the OIDC environment variables to the `simplesamlphp-admin` Secret (or a
separate Secret) and reference them as additional `env` entries in the
Deployment:

```bash
kubectl create secret generic simplesamlphp-oidc \
  --namespace simplesamlphp \
  --from-literal=SIMPLESAMLPHP_OIDC_ISSUER="https://accounts.google.com" \
  --from-literal=SIMPLESAMLPHP_OIDC_CLIENT_ID="your-client-id" \
  --from-literal=SIMPLESAMLPHP_OIDC_CLIENT_SECRET="your-client-secret"
```

Then add to the `env:` section of the Deployment:

```yaml
- name: SIMPLESAMLPHP_OIDC_ISSUER
  valueFrom:
    secretKeyRef:
      name: simplesamlphp-oidc
      key: SIMPLESAMLPHP_OIDC_ISSUER
- name: SIMPLESAMLPHP_OIDC_CLIENT_ID
  valueFrom:
    secretKeyRef:
      name: simplesamlphp-oidc
      key: SIMPLESAMLPHP_OIDC_CLIENT_ID
- name: SIMPLESAMLPHP_OIDC_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: simplesamlphp-oidc
      key: SIMPLESAMLPHP_OIDC_CLIENT_SECRET
```

See [OIDC setup guide](oidc.md) for the full configuration instructions.

---

## Scaling

Sessions are stored in Memcached, so the Deployment can be scaled horizontally
without losing active sessions:

```bash
kubectl -n simplesamlphp scale deployment/simplesamlphp --replicas=3
```

> The log PVC must use **ReadWriteMany** access mode when running more than one
> replica.  Each pod writes to its own sub-directory (named after the pod name)
> to avoid conflicts.

---

## TLS termination options

| Option | Description |
|--------|-------------|
| **In-pod TLS (default)** | Apache terminates TLS inside the container using a TLS Secret mounted at `/etc/ssl/simplesamlphp/` |
| **Ingress / cert-manager** | Use an Ingress resource with `nginx.ingress.kubernetes.io/ssl-passthrough: "true"` or configure the Ingress to re-encrypt to the pod, and switch the Service to `ClusterIP` |
| **Istio / service mesh** | Disable in-pod TLS and rely on mTLS provided by the mesh |

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Pod stuck in `Pending` | PVC not bound | Check `kubectl get pvc -n simplesamlphp`; ensure the StorageClass supports the access mode |
| `ImagePullBackOff` | Image not found or registry credentials missing | Verify the image tag exists and create an `imagePullSecret` if the registry is private |
| Pod restarts repeatedly | Config error in entrypoint | Check `kubectl logs -n simplesamlphp <pod>` for startup errors |
| `503 Service Unavailable` from the LoadBalancer | Pod not ready | Wait for the readiness probe to pass; check `kubectl describe pod` |
| Sessions lost on pod restart | `SIMPLESAMLPHP_SECRET_SALT` regenerated | Set a stable `SIMPLESAMLPHP_SECRET_SALT` in the Secret |
