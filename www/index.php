<?php
declare(strict_types=1);

/**
 * index.php – Protocol-selection landing page.
 *
 * Presents testers with a choice between two authentication methods:
 *   • SAML 2.0 – redirects to /secure/ (default-sp auth source)
 *   • OpenID Connect – redirects to /secure/oidc.php (oidc-sp auth source)
 */
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SimpleSAMLphp – Authentication Test</title>
    <link rel="stylesheet" href="/css/style.css">
    <style>
        .protocol-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 1.5rem;
            margin-top: 1.5rem;
        }

        @media (max-width: 520px) {
            .protocol-grid {
                grid-template-columns: 1fr;
            }
        }

        .protocol-card {
            border: 2px solid var(--clr-border);
            border-radius: var(--radius);
            padding: 1.5rem;
            text-align: center;
            transition: border-color 0.15s, box-shadow 0.15s;
            background: var(--clr-surface);
        }

        .protocol-card:hover {
            border-color: var(--clr-accent);
            box-shadow: var(--shadow);
        }

        .protocol-icon {
            font-size: 2.5rem;
            margin-bottom: 0.75rem;
            display: block;
        }

        .protocol-title {
            font-size: 1.1rem;
            font-weight: 700;
            color: var(--clr-primary);
            margin-bottom: 0.5rem;
        }

        .protocol-desc {
            font-size: 0.825rem;
            color: var(--clr-muted);
            margin-bottom: 1.25rem;
            line-height: 1.5;
        }
    </style>
</head>
<body>

<header class="site-header">
    <a class="brand" href="/"><span>Simple</span>SAMLphp</a>
    <nav>
        <a href="/simplesaml/">Admin UI</a>
    </nav>
</header>

<main class="site-main">
    <div class="card">

        <h1 class="card-title">
            <span class="icon">&#128272;</span>
            Authentication Test
        </h1>

        <div class="alert alert-info">
            &#8505;&nbsp; Select a protocol below to test authentication.
            You will be redirected to the identity provider and then returned
            here with your identity attributes displayed.
        </div>

        <div class="protocol-grid">

            <div class="protocol-card">
                <span class="protocol-icon">&#128196;</span>
                <div class="protocol-title">SAML 2.0</div>
                <p class="protocol-desc">
                    Authenticate via a SAML 2.0 Identity Provider using the
                    <code>default-sp</code> authentication source.
                    Configure your IdP in
                    <code>metadata/saml20-idp-remote.php</code>.
                </p>
                <a class="btn" href="/secure/">Test SAML</a>
            </div>

            <div class="protocol-card">
                <span class="protocol-icon">&#128273;</span>
                <div class="protocol-title">OpenID Connect</div>
                <p class="protocol-desc">
                    Authenticate via an OpenID Connect provider using the
                    <code>oidc-sp</code> authentication source.
                    Set <code>SIMPLESAMLPHP_OIDC_ISSUER</code>,
                    <code>SIMPLESAMLPHP_OIDC_CLIENT_ID</code>, and
                    <code>SIMPLESAMLPHP_OIDC_CLIENT_SECRET</code> to enable.
                </p>
                <a class="btn btn-outline" href="/secure/oidc.php">Test OIDC</a>
            </div>

        </div>

    </div>
</main>

<footer class="site-footer">
    &copy; <?= date('Y') ?> SimpleSAMLphp Demo &mdash; Powered by
    <a href="https://simplesamlphp.org/" rel="noopener noreferrer">SimpleSAMLphp</a>
</footer>

</body>
</html>
