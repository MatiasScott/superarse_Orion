<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Config;
use App\Core\Container;
use App\Core\Database;
use App\Core\Request;
use PDO;
use Throwable;

final class HealthController
{
    public function index(Request $request): void
    {
        /** @var Config $config */
        $config = Container::get(Config::class);

        if (($config->get('APP_ENV', 'production')) !== 'local') {
            http_response_code(404);
            echo 'Página no encontrada.';
            return;
        }

        header('Content-Type: application/json; charset=utf-8');

        try {
            /** @var Database $database */
            $database = Container::get(Database::class);
            $pdo = $database->connection();

            $version = (string)$pdo->query('SELECT VERSION()')->fetchColumn();

            $stmt = $pdo->prepare(
                "SELECT COUNT(*)
                   FROM information_schema.tables
                  WHERE table_schema = DATABASE()
                    AND table_type = 'BASE TABLE'"
            );
            $stmt->execute();
            $tables = (int)$stmt->fetchColumn();

            $checks = [];
            foreach (['personas','usuarios','perfiles','roles','permisos','cuentas_institucionales'] as $table) {
                $q = $pdo->prepare(
                    "SELECT COUNT(*)
                       FROM information_schema.tables
                      WHERE table_schema = DATABASE()
                        AND table_name = ?"
                );
                $q->execute([$table]);
                $checks[$table] = (bool)$q->fetchColumn();
            }

            echo json_encode([
                'app' => 'Orion',
                'status' => 'ok',
                'environment' => 'local',
                'php' => PHP_VERSION,
                'pdo_mysql' => extension_loaded('pdo_mysql'),
                'database' => [
                    'connected' => true,
                    'engine_version' => $version,
                    'schema' => (string)$pdo->query('SELECT DATABASE()')->fetchColumn(),
                    'tables' => $tables,
                    'core_tables' => $checks,
                ],
            ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        } catch (Throwable $e) {
            http_response_code(500);
            echo json_encode([
                'app' => 'Orion',
                'status' => 'error',
                'database' => ['connected' => false],
                'message' => $config->bool('APP_DEBUG')
                    ? $e->getMessage()
                    : 'No fue posible comprobar la base de datos.'
            ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
        }
    }
}
