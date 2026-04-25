<?php
declare(strict_types=1);

/**
 * secure/index.php – SAML-protected example page.
 *
 * Requires a valid authentication session from SimpleSAMLphp (default-sp
 * auth source).  On success the page displays the authenticated user's
 * NameID, e-mail address, given name and surname that were delivered in
 * the SAML assertion.
 *
 * A correlation / request ID (injected by Apache mod_unique_id as the
 * UNIQUE_ID environment variable and forwarded as the X-Request-ID response
 * header) is shown on the page so that any browser-visible problem can be
 * correlated with the corresponding Apache access-log entry.
 */

require_once '/var/simplesamlphp/vendor/autoload.php';

// ---------------------------------------------------------------------------
// Require authentication – redirects to the IdP if no session exists.
// ---------------------------------------------------------------------------
$as = new \SimpleSAML\Auth\Simple('default-sp');
$as->requireAuth();

// ---------------------------------------------------------------------------
// Retrieve SAML attributes delivered in the assertion.
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

// E-mail (OID 0.9.2342.19200300.100.1.3 = mail)
$email = $attr($attributes, [
    'mail',
    'email',
    'urn:oid:0.9.2342.19200300.100.1.3',
]);

// Given name (OID 2.5.4.42 = givenName)
$firstName = $attr($attributes, [
    'givenName',
    'given_name',
    'firstname',
    'urn:oid:2.5.4.42',
]);

// Surname (OID 2.5.4.4 = sn)
$lastName = $attr($attributes, [
    'sn',
    'surname',
    'last_name',
    'lastname',
    'urn:oid:2.5.4.4',
]);

// ---------------------------------------------------------------------------
// Retrieve NameID.
// In SimpleSAMLphp 2.x getAuthData('saml:sp:NameID') returns a
// \SimpleSAML\SAML2\XML\saml\NameID object (saml/saml2 library ≥ 4).
// Earlier builds and some edge-cases return an array or a plain string.
// ---------------------------------------------------------------------------
$nameId = '';
$nameIdFormat = '';
$nameIdObj = $as->getAuthData('saml:sp:NameID');
if ($nameIdObj !== null) {
    if (is_object($nameIdObj)) {
        // SAML2 library ≥ 4: getContent() returns the identifier value.
        if (method_exists($nameIdObj, 'getContent')) {
            $nameId = $nameIdObj->getContent();
        } elseif (method_exists($nameIdObj, 'getValue')) {
            $nameId = $nameIdObj->getValue();
        } else {
            $nameId = (string) $nameIdObj;
        }
        if (method_exists($nameIdObj, 'getFormat')) {
            $nameIdFormat = (string) $nameIdObj->getFormat();
        }
    } elseif (is_array($nameIdObj)) {
        $nameId       = (string) ($nameIdObj['Value']  ?? '');
        $nameIdFormat = (string) ($nameIdObj['Format'] ?? '');
    } else {
        $nameId = (string) $nameIdObj;
    }
}

// ---------------------------------------------------------------------------
// Correlation / request ID – set by Apache mod_unique_id and exposed as
// $_SERVER['UNIQUE_ID'] inside PHP.
// ---------------------------------------------------------------------------
$requestId = (string) ($_SERVER['UNIQUE_ID'] ?? '');

// ---------------------------------------------------------------------------
// Logout URL
// Derive the return-to URL from the server-side configured baseurlpath so
// that the Host header (which is client-controlled) is never trusted.
// ---------------------------------------------------------------------------
$_sspConfig  = \SimpleSAML\Configuration::getInstance();
$_baseUrl    = $_sspConfig->getString('baseurlpath', 'https://localhost/simplesaml/');
$_parsed     = parse_url($_baseUrl);
$_siteRoot   = ($_parsed['scheme'] ?? 'https') . '://' . ($_parsed['host'] ?? 'localhost') . '/';
$logoutUrl   = htmlspecialchars($as->getLogoutURL($_siteRoot), ENT_QUOTES, 'UTF-8');

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

// Shorten the NameID format URN for display.
$nameIdFormatShort = str_replace(
    'urn:oasis:names:tc:SAML:2.0:nameid-format:',
    '',
    $nameIdFormat
);

$displayName = trim($firstName . ' ' . $lastName);
$pageTitle   = $displayName !== '' ? $displayName : ($email !== '' ? $email : 'Authenticated User');
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Secure Page – SimpleSAMLphp</title>
    <link rel="stylesheet" href="/css/style.css">
</head>
<body>

<header class="site-header">
    <a class="brand" href="/"><span>Simple</span>SAMLphp</a>
    <nav>
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
            &#10003;&nbsp; You have been successfully authenticated via SAML&nbsp;2.0.
            The attributes below were delivered in the SAML assertion.
        </div>

        <table class="attr-table">
            <thead>
                <tr>
                    <th>Attribute</th>
                    <th>Value</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td class="attr-name">NameID</td>
                    <td><?= $display($nameId) ?></td>
                </tr>
                <?php if ($nameIdFormatShort !== ''): ?>
                <tr>
                    <td class="attr-name">NameID Format</td>
                    <td><?= $display($nameIdFormatShort) ?></td>
                </tr>
                <?php endif; ?>
                <tr>
                    <td class="attr-name">First Name</td>
                    <td><?= $display($firstName) ?></td>
                </tr>
                <tr>
                    <td class="attr-name">Last Name</td>
                    <td><?= $display($lastName) ?></td>
                </tr>
                <tr>
                    <td class="attr-name">E-mail</td>
                    <td><?= $display($email) ?></td>
                </tr>
            </tbody>
        </table>

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
