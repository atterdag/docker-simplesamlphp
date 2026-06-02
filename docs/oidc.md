# OpenID Connect (OIDC) Relying Party setup

This guide explains how to configure `docker-simplesamlphp` as an OpenID
Connect (OIDC) Relying Party (RP) using the
[`cirrusidentity/simplesamlphp-module-authoauth2`](https://github.com/cirrusidentity/simplesamlphp-module-authoauth2)
module that is pre-installed in the image.

---

## How it works

The container exposes an authentication source called **`oidc-sp`** (defined
in `authsources.php`).  When all three `SIMPLESAMLPHP_OIDC_*` environment
variables are set, this source becomes functional and redirects users to your
OpenID Connect provider for authentication.

The provider **must** support
[OpenID Connect Discovery](https://openid.net/specs/openid-connect-discovery-1_0.html)
(`<issuer>/.well-known/openid-configuration`).  All major providers (Google,
Microsoft Entra ID, Keycloak, Auth0, Okta, GitLab, …) support this.

---

## Prerequisites

* A running instance of `docker-simplesamlphp` (see [SAML SP setup](saml-sp.md) for the general setup)
* An OIDC provider where you can register a client application
* The FQDN of your SimpleSAMLphp instance (e.g. `simplesamlphp.example.org`)

---

## Step 1 – Register a client with your OIDC provider

The procedure differs per provider, but you will always need to:

1. Create a new **web application** or **OAuth 2.0 client**.
2. Set the **Redirect URI** (also called *callback URL*) to:
   ```
   https://simplesamlphp.example.org/simplesaml/module.php/authoauth2/linkback.php
   ```
3. Note down the **Client ID** and **Client Secret** issued by the provider.
4. Note down the **Issuer URL** (sometimes labelled *Discovery URL base*,
   *Tenant ID URL*, or *OpenID configuration endpoint* minus the
   `/.well-known/openid-configuration` suffix).

### Provider-specific notes

#### Google

* Console: [APIs & Services → Credentials → Create OAuth client ID](https://console.cloud.google.com/apis/credentials)
* Application type: **Web application**
* Issuer URL: `https://accounts.google.com`

#### Microsoft Entra ID (Azure AD)

* Portal: **App registrations → New registration**
* Set **Redirect URI** type to *Web*.
* Issuer URL format:
  * Single-tenant: `https://login.microsoftonline.com/<tenant-id>/v2.0`
  * Multi-tenant: `https://login.microsoftonline.com/common/v2.0`
* Generate a **Client secret** under *Certificates & secrets*.

#### Keycloak

* Admin console: **Realm → Clients → Create client**
* Client type: **OpenID Connect**, access type: **Confidential**
* Issuer URL: `https://keycloak.example.org/realms/<realm-name>`

#### Auth0

* Dashboard: **Applications → Create Application → Regular Web Applications**
* Issuer URL: `https://<tenant>.auth0.com`

#### Okta

* Admin console: **Applications → Create App Integration → OIDC – Web Application**
* Issuer URL: `https://<tenant>.okta.com`

---

## Step 2 – Set environment variables

Pass the three OIDC variables when starting the container.

### Docker Compose

Add to the `environment:` block in `docker-compose.yml`:

```yaml
SIMPLESAMLPHP_OIDC_ISSUER:        https://accounts.google.com   # change as needed
SIMPLESAMLPHP_OIDC_CLIENT_ID:     your-client-id
SIMPLESAMLPHP_OIDC_CLIENT_SECRET: your-client-secret
```

Then restart the stack:

```bash
docker compose up -d
```

### docker run

```bash
docker run -d \
  -e DOMAIN_NAME=example.org \
  -e SERVER_NAME=simplesamlphp \
  -e SIMPLESAMLPHP_ADMIN_PASSWORD="<strong-password>" \
  -e SIMPLESAMLPHP_OIDC_ISSUER="https://accounts.google.com" \
  -e SIMPLESAMLPHP_OIDC_CLIENT_ID="your-client-id" \
  -e SIMPLESAMLPHP_OIDC_CLIENT_SECRET="your-client-secret" \
  -p 80:80 -p 443:443 \
  ghcr.io/atterdag/docker-simplesamlphp:latest
```

---

## Step 3 – Verify the OIDC configuration

1. Browse to `https://simplesamlphp.example.org/simplesaml/`.
2. Log in with the admin password.
3. Click **Authentication** → **Test configured authentication sources**.
4. Select **oidc-sp** and click **Login**.
5. You are redirected to your OIDC provider's login page.
6. After successful login you are redirected back; the page shows the claims
   returned by the provider (e.g. `sub`, `name`, `email`).

---

## Step 4 – Use OIDC in a SAML federation (bridging)

A common use-case is to offer SAML-federated access to an application while
authenticating users against an OIDC provider (OIDC-to-SAML bridge).

To bridge OIDC into the SAML SP, configure the `default-sp` authentication
source to use `oidc-sp` as its IdP via an **authproc** filter, or configure
your application to use `oidc-sp` directly as the authentication source.

The SimpleSAMLphp
[authproc documentation](https://simplesamlphp.org/docs/stable/simplesamlphp-authproc)
describes how to chain authentication sources.

---

## Key environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `SIMPLESAMLPHP_OIDC_ISSUER` | Yes | Issuer URL of the OIDC provider |
| `SIMPLESAMLPHP_OIDC_CLIENT_ID` | Yes | Client ID registered with the provider |
| `SIMPLESAMLPHP_OIDC_CLIENT_SECRET` | Yes | Client secret |

The redirect/callback URI registered with the provider must be:

```
https://<FQDN>/simplesaml/module.php/authoauth2/linkback.php
```

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `Discovery document not found` | Wrong issuer URL | Verify that `<issuer>/.well-known/openid-configuration` returns a JSON document |
| `redirect_uri_mismatch` | Redirect URI mismatch at the provider | Register `https://<FQDN>/simplesaml/module.php/authoauth2/linkback.php` exactly |
| `invalid_client` | Wrong Client ID or secret | Double-check the credentials in the provider dashboard |
| Container shows empty claims | Scopes not granted | Ensure the provider grants `openid`, `profile`, and `email` scopes for the client |
| HTTPS required error | Provider rejects non-HTTPS callback | Ensure Apache is configured with a valid TLS certificate and the container is reachable via HTTPS |
