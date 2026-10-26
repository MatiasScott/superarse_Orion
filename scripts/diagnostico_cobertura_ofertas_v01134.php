<?php

declare(strict_types=1);

/**
 * Orion v0.11.34 - Fase 2F
 * Diagnóstico de cobertura de ofertas académicas.
 * SOLO LECTURA.
 */

require dirname(__DIR__) . '/vendor/autoload.php';

use App\Core\Config;
use App\Core\Database;
use Dotenv\Dotenv;

Dotenv::createImmutable(dirname(__DIR__))->safeLoad();

$db = (new Database(new Config($_ENV)))->connection();

$file = dirname(__DIR__)
    . '/storage/conciliacion/v01134/detalle_conciliacion.csv';

$h = fopen($file, 'rb');

if (!$h) {
    exit("No se pudo abrir el reporte CSV.\n");
}

$headers = fgetcsv($h);
$idx = array_flip($headers);

foreach (['clasificacion', 'carrera_id', 'periodos_ids', 'trayectorias_ids'] as $col) {
    if (!array_key_exists($col, $idx)) {
        fclose($h);
        exit("Falta columna: {$col}\n");
    }
}

$parseIds = static function (string $value): array {
    preg_match_all('/\d+/', $value, $matches);

    return array_values(array_unique(array_map(
        'intval',
        $matches[0]
    )));
};

$offers = [];

foreach (
    $db->query("
    SELECT
        id,
        periodo_academico_id,
        carrera_id,
        malla_id,
        sede_id,
        modalidad_academica_id,
        activo
    FROM ofertas_academicas
") as $r
) {

    $key = (int)$r['carrera_id']
        . '|'
        . (int)$r['periodo_academico_id'];

    $offers[$key][] = $r;
}

$trajectories = [];

foreach (
    $db->query("
    SELECT id, malla_id, sede_id, modalidad_academica_id
    FROM estudiante_carreras
    WHERE deleted_at IS NULL
") as $r
) {
    $trajectories[(int)$r['id']] = $r;
}

$stats = [
    'SIN_OFERTA_CARRERA_PERIODO' => 0,
    'OFERTA_CARRERA_PERIODO_EXISTENTE' => 0,
    'OFERTA_MALLA_COMPATIBLE' => 0,
    'OFERTA_SEDE_COMPATIBLE' => 0,
    'OFERTA_EXACTA' => 0,
    'PERIODO_AMBIGUO' => 0,
    'OFERTA_ESTRUCTURAL_COMPATIBLE' => 0,
    'MODALIDAD_PENDIENTE' => 0,
    'MODALIDAD_CONFIRMADA' => 0,
    'MODALIDAD_CONFLICTO' => 0,
];

$total = 0;

while (($r = fgetcsv($h)) !== false) {

    if (($r[$idx['clasificacion']] ?? '') !== 'MATRICULA_PENDIENTE') {
        continue;
    }

    $total++;

    $careerId = (int)($r[$idx['carrera_id']] ?? 0);
    $periodIds = $parseIds((string)($r[$idx['periodos_ids']] ?? ''));
    $trajectoryIds = $parseIds((string)($r[$idx['trayectorias_ids']] ?? ''));

    if ($careerId <= 0 || count($periodIds) !== 1) {
        $stats['PERIODO_AMBIGUO']++;
        continue;
    }

    $key = $careerId . '|' . $periodIds[0];
    $candidates = $offers[$key] ?? [];

    if (!$candidates) {
        $stats['SIN_OFERTA_CARRERA_PERIODO']++;
        continue;
    }

    $stats['OFERTA_CARRERA_PERIODO_EXISTENTE']++;

    $malla = false;
    $sede = false;
    $exacta = false;
    $estructural = false;
    $modalidadPendiente = false;
    $modalidadConfirmada = false;
    $modalidadConflicto = false;

    foreach ($trajectoryIds as $tid) {

        if (!isset($trajectories[$tid])) {
            continue;
        }

        $t = $trajectories[$tid];

        foreach ($candidates as $o) {

            $sameMalla = (int)$o['malla_id'] === (int)$t['malla_id'];

            $sameSede = $o['sede_id'] !== null
                && $t['sede_id'] !== null
                && (int)$o['sede_id'] === (int)$t['sede_id'];

            if ($sameMalla && $sameSede) {

                $estructural = true;

                if ($sameMalla) {
                    $malla = true;
                }

                if ($sameSede) {
                    $sede = true;
                }

                $modalidadOferta = $o['modalidad_academica_id'];
                $modalidadTrayectoria = $t['modalidad_academica_id'];

                if (
                    $modalidadOferta === null ||
                    $modalidadTrayectoria === null
                ) {
                    $modalidadPendiente = true;
                } elseif (
                    (int)$modalidadOferta === (int)$modalidadTrayectoria
                ) {
                    $modalidadConfirmada = true;
                    $exacta = true;
                } else {
                    $modalidadConflicto = true;
                }
            }
        }
    }

    if ($malla) $stats['OFERTA_MALLA_COMPATIBLE']++;
    if ($sede) $stats['OFERTA_SEDE_COMPATIBLE']++;
    if ($exacta) $stats['OFERTA_EXACTA']++;
    if ($estructural) $stats['OFERTA_ESTRUCTURAL_COMPATIBLE']++;
    if ($modalidadPendiente) $stats['MODALIDAD_PENDIENTE']++;
    if ($modalidadConfirmada) $stats['MODALIDAD_CONFIRMADA']++;
    if ($modalidadConflicto) $stats['MODALIDAD_CONFLICTO']++;
}

fclose($h);

echo "ORION v0.11.34 - COBERTURA DE OFERTAS\n";
echo "====================================\n";
echo "Filas pendientes analizadas: {$total}\n\n";

foreach ($stats as $name => $count) {
    printf("%-43s %d\n", $name, $count);
}

echo "\nNOTA: Los indicadores de malla, sede y oferta exacta\n";
echo "son subconjuntos y pueden superponerse.\n";
echo "No se modificaron datos.\n";
