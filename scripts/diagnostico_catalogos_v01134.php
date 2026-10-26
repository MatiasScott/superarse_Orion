<?php
declare(strict_types=1);

/**
 * Orion v0.11.34 — Diagnóstico de catálogos
 * SOLO LECTURA
 */

require dirname(__DIR__) . '/vendor/autoload.php';

use App\Core\Config;
use App\Core\Database;
use Dotenv\Dotenv;

Dotenv::createImmutable(dirname(__DIR__))->safeLoad();

$db = (new Database(new Config($_ENV)))->connection();

$queries = [
    'CARRERAS' => "
        SELECT id, codigo, nombre, activo
        FROM carreras
        WHERE deleted_at IS NULL
        ORDER BY nombre
    ",

    'SEDES' => "
        SELECT id, codigo, nombre, activo
        FROM sedes
        WHERE deleted_at IS NULL
        ORDER BY nombre
    ",

    'PERIODOS' => "
        SELECT id, codigo, nombre,
               fecha_inicio, fecha_fin, activo
        FROM periodos_academicos
        WHERE deleted_at IS NULL
        ORDER BY fecha_inicio
    ",

    'NIVELES' => "
        SELECT id, codigo, nombre, orden_nivel
        FROM niveles_academicos
        ORDER BY orden_nivel
    ",

    'MALLAS' => "
        SELECT
            m.id,
            m.codigo,
            m.nombre,
            m.version,
            m.carrera_id,
            c.nombre AS carrera,
            m.activo
        FROM mallas_curriculares m
        INNER JOIN carreras c ON c.id = m.carrera_id
        WHERE m.deleted_at IS NULL
        ORDER BY c.nombre, m.version
    "
];

foreach ($queries as $name => $sql) {
    echo PHP_EOL;
    echo "========== {$name} ==========" . PHP_EOL;

    try {
        $stmt = $db->query($sql);

        foreach ($stmt as $row) {
            echo json_encode(
                $row,
                JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
            ) . PHP_EOL;
        }
    } catch (Throwable $e) {
        echo "ERROR: " . $e->getMessage() . PHP_EOL;
    }
}

echo PHP_EOL;
echo "FIN: Diagnóstico de solo lectura." . PHP_EOL;
