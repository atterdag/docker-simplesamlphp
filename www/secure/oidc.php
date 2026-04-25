<?php
declare(strict_types=1);

/**
 * secure/oidc.php – OpenID Connect protected example page.
 *
 * Requires a valid authentication session from SimpleSAMLphp (oidc-sp
 * auth source).  On success the page displays the authenticated user's
 * claims that were delivered in the OIDC ID token and/or userinfo response.
 *
 * Configure the oidc-sp auth source by setting:
 *   SIMPLESAMLPHP_OIDC_ISSUER        – OpenID Connect provider issuer URL
 *   SIMPLESAMLPHP_OIDC_CLIENT_ID     – client ID registered with the provider
 *   SIMPLESAMLPHP_OIDC_CLIENT_SECRET – client secret
 *
 * The callback/redirect URI to register with your provider is:
 *   https://<FQDN>/simplesaml/module.php/authoauth2/linkback.php
 *
 * A correlation / request ID (injected by Apache mod_unique_id as the
 * UNIQUE_ID environment variable and forwarded as the X-Request-ID response
 * header) is shown on the page so that any browser-visible problem can be
 * correlated with the corresponding Apache access-log entry.
 */

require_once '/var/simplesamlphp/vendor/autoload.php';

// ---------------------------------------------------------------------------
// Require authentication – redirects to the OIDC provider if no session exists.
// ---------------------------------------------------------------------------
$as = new \SimpleSAML\Auth\Simple('oidc-sp');
$as->requireAuth();

// ---------------------------------------------------------------------------
// Retrieve OIDC claims delivered as SimpleSAMLphp attributes.
// authoauth2 maps OIDC claim names directly to attribute keys.
// ---------------------------------------------------------------------------
$attributes = $as->getAttributes();

/**
 * Return the first non-empty value for the given attribute keys, or the
 * supplied default when none of the keys are present.
 */
$attr = static function (array $attributes, array $keys, string $default = ''): string {
    foreach ($keys as $key) {
        if (!empty($attributes[$key][0])) {
            return (string) $attributes[$key][0];
        }
    }
    return $default;
};

// Subject identifier (mandatory OIDC claim)
$sub = $attr($attributes, ['sub']);

// E-mail
$email = $attr($attributes, ['email']);

// Given name / first name
$firstName = $attr($attributes, ['given_name', 'firstname']);

// Family name / last name
$lastName = $attr($attributes, ['family_name', 'lastname']);

// Full display name (may be provided directly by some providers)
$displayNameFull = $attr($attributes, ['name']);

// ---------------------------------------------------------------------------
// Correlation / request ID – set by Apache mod_unique_id and exposed as
// $_SERVER['UNIQUE_ID'] inside PHP.
// ---------------------------------------------------------------------------
$requestId = (string) ($_SERVER['UNIQUE_ID'] ?? '');

// ---------------------------------------------------------------------------
// Logout URL
// ---------------------------------------------------------------------------
$logoutUrl = htmlspecialchars(
    $as->getLogoutURL(
        (isset($_SERVER['HTTPS']) ? 'https' : 'http')
        . '://' . ($_SERVER['HTTP_HOST'] ?? 'localhost') . '/'
    ),
    ENT_QUOTES,
    'UTF-8'
);

// ---------------------------------------------------------------------------
// Helper: safely HTML-encode a value for output; return an italic
// "(not provided)" marker when the value is empty.
// ---------------------------------------------------------------------------
$display = static function (string $value): string {
    if ($value === '') {
        return '<span class="attr-value empty">(not provided)</span>';
    }
    return sprintf(
        '<span class="attr-value">%s</span>',
        htmlspecialchars($value, ENT_QUOTES, 'UTF-8')
    );
};

// Derive a page title from available claims.
$derivedName = trim($firstName . ' ' . $lastName);
if ($displayNameFull !== '') {
    $pageTitle = $displayNameFull;
} elseif ($derivedName !== '') {
    $pageTitle = $derivedName;
} elseif ($email !== '') {
    $pageTitle = $email;
} else {
    $pageTitle = 'Authenticated User';
}

// ---------------------------------------------------------------------------
// Build a table of all raw attributes for extended inspection.
// Sort by key for predictable display order.
// ---------------------------------------------------------------------------
ksort($attributes);
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Secure Page (OIDC) – SimpleSAMLphp</title>
    <link rel="stylesheet" href="/css/style.css">
</head>
<body>

<header class="site-header">
    <a class="brand" href="/"><span>Simple</span>SAMLphp</a>
    <nav>
        <span class="badge badge-info">&#128273;&nbsp;OpenID Connect</span>
        <span class="badge badge-success">&#10003;&nbsp;Authenticated</span>
        <a class="btn-logout" href="<?= $logoutUrl ?>">Sign out</a>
    </nav>
</header>

<main class="site-main">
    <div class="card">

        <h1 class="card-title">
            <span class="icon">&#128100;</span>
            Welcome, <?= htmlspecialchars($pageTitle, ENT_QUOTES, 'UTF-8') ?>
        </h1>

        <div class="alert alert-success">
            &#10003;&nbsp; You have been successfully authenticated via OpenID Connect.
            The claims below were delivered in the OIDC ID token / userinfo response.
        </div>

        <table class="attr-table">
            <thead>
                <tr>
                    <th>Claim</th>
                    <th>Value</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td class="attr-name">Subject (sub)</td>
                    <td><?= $display($sub) ?></td>
                </tr>
                <tr>
                    <td class="attr-name">First Name</td>
                    <td><?= $display($firstName) ?></td>
                </tr>
                <tr>
                    <td class="attr-name">Last Name</td>
                    <td><?= $display($lastName) ?></td>
                </tr>
                <tr>
                    <td class="attr-name">Full Name</td>
                    <td><?= $display($displayNameFull) ?></td>
                </tr>
                <tr>
                    <td class="attr-name">E-mail</td>
                    <td><?= $display($email) ?></td>
                </tr>
            </tbody>
        </table>

        <?php if (!empty($attributes)): ?>
        <details style="margin-bottom: 1.5rem;">
            <summary style="cursor:pointer; font-weight:600; color:var(--clr-primary-md); font-size:0.875rem; padding:0.5rem 0;">
                All claims (<?= count($attributes) ?>)
            </summary>
            <table class="attr-table" style="margin-top:0.75rem;">
                <thead>
                    <tr>
                        <th>Claim</th>
                        <th>Value</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($attributes as $name => $values): ?>
                    <tr>
                        <td class="attr-name"><?= htmlspecialchars((string) $name, ENT_QUOTES, 'UTF-8') ?></td>
                        <td><?= $display(implode(', ', array_map('strval', (array) $values))) ?></td>
                    </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </details>
        <?php endif; ?>

        <?php if ($requestId !== ''): ?>
        <div class="request-id-bar">
            <span class="rid-label">Request&nbsp;ID</span>
            <span class="rid-value"><?= htmlspecialchars($requestId, ENT_QUOTES, 'UTF-8') ?></span>
        </div>
        <?php endif; ?>

    </div>
</main>

<footer class="site-footer">
    &copy; <?= date('Y') ?> SimpleSAMLphp Demo &mdash; Powered by
    <a href="https://simplesamlphp.org/" rel="noopener noreferrer">SimpleSAMLphp</a>
</footer>

</body>
</html>
