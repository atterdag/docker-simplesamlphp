<?php

/**
 * SAML 2.0 remote IdP metadata for SimpleSAMLphp.
 *
 * This file is the default shipped inside the image.  Replace or overlay it
 * at runtime by bind-mounting your own file to:
 *
 *   /var/simplesamlphp/metadata/saml20-idp-remote.php
 *
 * Docker Compose example:
 *   volumes:
 *     - ./my-idp-metadata.php:/var/simplesamlphp/metadata/saml20-idp-remote.php:ro
 *
 * Kubernetes ConfigMap example (in your Pod/Deployment spec):
 *   volumes:
 *     - name: idp-metadata
 *       configMap:
 *         name: simplesamlphp-idp-metadata
 *   containers:
 *     - volumeMounts:
 *         - name: idp-metadata
 *           mountPath: /var/simplesamlphp/metadata/saml20-idp-remote.php
 *           subPath: saml20-idp-remote.php
 *           readOnly: true
 *
 * See https://simplesamlphp.org/docs/stable/simplesamlphp-reference-idp-remote
 * for the full reference of available metadata options.
 *
 * Example entry:
 *
 * $metadata['https://idp.example.org/'] = [
 *     'name' => [
 *         'en' => 'Example IdP',
 *     ],
 *     'description' => 'Example Identity Provider',
 *     'SingleSignOnService' => 'https://idp.example.org/saml/SSO',
 *     'SingleLogoutService'  => 'https://idp.example.org/saml/SLO',
 *     'certData' => '...base64-encoded-certificate...',
 * ];
 */
