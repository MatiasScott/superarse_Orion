<?php

declare(strict_types=1);

/**
 * Orion v0.11.34 - Fase 2F
 * Cruce de matrículas pendientes.
 *
 * SOLO LECTURA:
 * - SELECT en MySQL.
 * - Lectura del reporte CSV.
 * - No modifica información académica.
 */

require dirname(__DIR__) . '/vendor/autoload.php';

use App\Core\Config;
use App\Core\Database;
use Dotenv\Dotenv;

Dotenv::createImmutable(dirname(__DIR__))->safeLoad();

$db = (new Database(new Config($_ENV)))->connection();

$file = dirname(__DIR__)
    . '/storage/conciliacion/v01134/detalle_conciliacion.csv';

if (!is_file($file)) {
    exit("No existe el reporte de conciliación.\n");
}

$h = fopen($file, 'rb');

if (!$h) {
    exit("No se pudo abrir el CSV.\n");
}

$headers = fgetcsv($h);
$idx = array_flip($headers);

$required = [
    'clasificacion',
    'estudiante_id',
    'carrera_id',
    'trayectorias_ids',
    'periodos_ids'
];

foreach ($required as $column) {
    if (!array_key_exists($column, $idx)) {
        exit("Falta columna: {$column}\n");
    }
}

/*
 * Cargar trayectorias.
 */
$trajectories = [];

$sql = "
    SELECT
        id,
        estudiante_id,
        carrera_id,
        malla_id,
        sede_id,
        activo,
        deleted_at
    FROM estudiante_carreras
";

foreach ($db->query($sql) as $r) {
    $trajectories[(int)$r['id']] = $r;
}

/*
 * Cargar matrículas.
 */
$enrollments = [];

$sql = "
    SELECT
        id,
        estudiante_carrera_id,
        periodo_academico_id,
        activo
    FROM matriculas
";

foreach ($db->query($sql) as $r) {

    $trajectoryId = (int)$r['estudiante_carrera_id'];

    if (!isset($trajectories[$trajectoryId])) {
        continue;
    }

    $trajectory = $trajectories[$trajectoryId];

    $studentId = (int)$trajectory['estudiante_id'];
    $periodId = (int)$r['periodo_academico_id'];

    $key = $studentId . '|' . $periodId;

    $enrollments[$key][] = [
        'matricula_id' => (int)$r['id'],
        'trayectoria_id' => $trajectoryId,
        'carrera_id' => (int)$trajectory['carrera_id'],
        'activo' => (int)$r['activo'],
        'trayectoria_eliminada' =>
        $trajectory['deleted_at'] !== null
    ];
}

/*
 * Clasificación.
 */
$stats = [
    'MISMA_TRAYECTORIA' => 0,
    'OTRA_TRAYECTORIA_MISMA_CARRERA' => 0,
    'OTRA_CARRERA' => 0,
    'SIN_MATRICULA_ESTUDIANTE_PERIODO' => 0,
    'SIN_DATOS_PARA_CRUCE' => 0
];

$parseIds = static function (string $value): array {
    preg_match_all('/\d+/', $value, $matches);

    return array_values(array_unique(array_map(
        'intval',
        $matches[0]
    )));
};

$total = 0;

while (($r = fgetcsv($h)) !== false) {

    if (($r[$idx['clasificacion']] ?? '')
        !== 'MATRICULA_PENDIENTE'
    ) {
        continue;
    }

    $total++;

    $studentId = (int)($r[$idx['estudiante_id']] ?? 0);
    $careerId = (int)($r[$idx['carrera_id']] ?? 0);

    $trajectoryIds = $parseIds(
        (string)($r[$idx['trayectorias_ids']] ?? '')
    );

    $periodIds = $parseIds(
        (string)($r[$idx['periodos_ids']] ?? '')
    );

    if (
        $studentId <= 0 ||
        $careerId <= 0 ||
        count($periodIds) !== 1 ||
        count($trajectoryIds) === 0
    ) {
        $stats['SIN_DATOS_PARA_CRUCE']++;
        continue;
    }

    $key = $studentId . '|' . $periodIds[0];

    $matches = $enrollments[$key] ?? [];

    $sameTrajectory = false;
    $sameCareer = false;
    $otherCareer = false;

    foreach ($matches as $m) {

        if (in_array(
            $m['trayectoria_id'],
            $trajectoryIds,
            true
        )) {
            $sameTrajectory = true;
        } elseif ($m['carrera_id'] === $careerId) {
            $sameCareer = true;
        } else {
            $otherCareer = true;
        }
    }

    if ($sameTrajectory) {
        $stats['MISMA_TRAYECTORIA']++;
    } elseif ($sameCareer) {
        $stats['OTRA_TRAYECTORIA_MISMA_CARRERA']++;
    } elseif ($otherCareer) {
        $stats['OTRA_CARRERA']++;
    } else {
        $stats['SIN_MATRICULA_ESTUDIANTE_PERIODO']++;
    }
}

fclose($h);

echo "ORION v0.11.34 - CRUCE DE MATRICULAS\n";
echo "===================================\n";
echo "Filas pendientes analizadas: {$total}\n\n";

foreach ($stats as $status => $count) {
    printf("%-43s %d\n", $status, $count);
}

echo "\nNo se modificaron datos.\n";
