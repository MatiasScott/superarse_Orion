<?php
declare(strict_types=1);
// Ejecutar desde raíz: php scripts/test_moodle_connection.php
$root = dirname(__DIR__);
require $root . '/vendor/autoload.php';
if (is_file($root . '/.env')) {
    Dotenv\Dotenv::createImmutable($root)->safeLoad();
}
try {
    $client = new App\Integrations\Moodle\MoodleRestClient($_ENV);
    $info = $client->siteInfo();
    echo "Conexión Moodle correcta\n";
    echo 'Sitio: ' . ($info['sitename'] ?? 'No disponible') . "\n";
    echo 'Usuario ID: ' . ($info['userid'] ?? 'No disponible') . "\n";
} catch (Throwable $e) {
    fwrite(STDERR, 'Error: ' . $e->getMessage() . "\n");
    exit(1);
}
