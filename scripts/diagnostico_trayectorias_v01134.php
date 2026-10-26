<?php
declare(strict_types=1);

require dirname(__DIR__) . '/vendor/autoload.php';

use App\Core\Config;
use App\Core\Database;
use Dotenv\Dotenv;

Dotenv::createImmutable(dirname(__DIR__))->safeLoad();

$db = (new Database(new Config($_ENV)))->connection();

$queries = [
    'TRAYECTORIAS POR CARRERA Y SEDE' => "
        SELECT
            ec.carrera_id,
            c.nombre AS carrera,
            ec.sede_id,
            s.nombre AS sede,
            COUNT(*) AS total
        FROM estudiante_carreras ec
        JOIN carreras c ON c.id = ec.carrera_id
        LEFT JOIN sedes s ON s.id = ec.sede_id
        WHERE ec.deleted_at IS NULL
        GROUP BY ec.carrera_id, c.nombre, ec.sede_id, s.nombre
        ORDER BY c.nombre, s.nombre
    ",

    'TRAYECTORIAS POR MALLA' => "
        SELECT
            ec.carrera_id,
            c.nombre AS carrera,
            ec.malla_id,
            m.nombre AS malla,
            COUNT(*) AS total
        FROM estudiante_carreras ec
        JOIN carreras c ON c.id = ec.carrera_id
        JOIN mallas_curriculares m ON m.id = ec.malla_id
        WHERE ec.deleted_at IS NULL
        GROUP BY ec.carrera_id, c.nombre, ec.malla_id, m.nombre
        ORDER BY c.nombre, ec.malla_id
    ",

    'TRAYECTORIAS CON CARRERA Y MALLA INCOMPATIBLES' => "
        SELECT COUNT(*)
        FROM estudiante_carreras ec
        JOIN mallas_curriculares m ON m.id = ec.malla_id
        WHERE ec.deleted_at IS NULL
          AND ec.carrera_id <> m.carrera_id
    ",

    'PERSONAS SIN EXPEDIENTE DE ESTUDIANTE' => "
        SELECT COUNT(*)
        FROM personas p
        LEFT JOIN estudiantes e
            ON e.persona_id = p.id
            AND e.deleted_at IS NULL
        WHERE p.deleted_at IS NULL
          AND e.id IS NULL
    ",

    'ESTUDIANTES SIN TRAYECTORIA' => "
        SELECT COUNT(*)
        FROM estudiantes e
        LEFT JOIN estudiante_carreras ec
            ON ec.estudiante_id = e.id
            AND ec.deleted_at IS NULL
        WHERE e.deleted_at IS NULL
          AND ec.id IS NULL
    "
];

foreach ($queries as $name => $sql) {
    echo PHP_EOL . "========== {$name} ==========" . PHP_EOL;

    $stmt = $db->query($sql);

    foreach ($stmt as $row) {
        echo json_encode(
            $row,
            JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
        ) . PHP_EOL;
    }
}

echo PHP_EOL . "FIN: Diagnóstico de solo lectura." . PHP_EOL;
