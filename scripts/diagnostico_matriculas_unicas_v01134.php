<?php

declare(strict_types=1);

/**
 * Orion v0.11.34
 * Diagnóstico de combinaciones únicas.
 * Solo lectura de CSV.
 */

$file = dirname(__DIR__)
    . '/storage/conciliacion/v01134/detalle_conciliacion.csv';

$h = fopen($file, 'rb');

if (!$h) {
    exit("No se pudo abrir el reporte.\n");
}

$headers = fgetcsv($h);
$idx = array_flip($headers);

$required = [
    'clasificacion',
    'estudiante_id',
    'carrera_id',
    'periodos_ids',
    'trayectorias_ids'
];

foreach ($required as $column) {
    if (!array_key_exists($column, $idx)) {
        fclose($h);
        exit("Falta columna: {$column}\n");
    }
}

$unique = [];
$duplicates = [];
$total = 0;
$withoutPeriod = 0;

while (($r = fgetcsv($h)) !== false) {

    if (($r[$idx['clasificacion']] ?? '')
        !== 'MATRICULA_PENDIENTE'
    ) {
        continue;
    }

    $total++;

    $studentId = trim($r[$idx['estudiante_id']] ?? '');
    $careerId = trim($r[$idx['carrera_id']] ?? '');
    $periodId = trim($r[$idx['periodos_ids']] ?? '');

    if (
        $studentId === '' ||
        $careerId === '' ||
        $periodId === ''
    ) {
        $withoutPeriod++;
        continue;
    }

    $key = $studentId . '|'
        . $careerId . '|'
        . $periodId;

    $unique[$key] = ($unique[$key] ?? 0) + 1;
}

fclose($h);

foreach ($unique as $key => $count) {
    if ($count > 1) {
        $duplicates[$key] = $count;
    }
}

$additional = array_sum(
    array_map(
        static fn($count) => $count - 1,
        $duplicates
    )
);

echo "ORION v0.11.34 - MATRICULAS UNICAS\n";
echo "=================================\n";

printf("%-45s %d\n", 'Filas pendientes', $total);
printf("%-45s %d\n", 'Combinaciones estudiante+carrera+periodo', count($unique));
printf("%-45s %d\n", 'Combinaciones repetidas', count($duplicates));
printf("%-45s %d\n", 'Filas adicionales por repeticion', $additional);
printf("%-45s %d\n", 'Filas sin identificadores suficientes', $withoutPeriod);

echo "\nNo se modificaron datos.\n";
