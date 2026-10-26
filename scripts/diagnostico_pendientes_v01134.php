<?php

declare(strict_types=1);

/**
 * Orion v0.11.34
 * Diagnóstico de matrículas pendientes.
 * Solo lectura de CSV. No modifica MySQL.
 */

$file = dirname(__DIR__)
    . '/storage/conciliacion/v01134/detalle_conciliacion.csv';

if (!is_file($file)) {
    exit("ERROR: No existe el archivo CSV.\n");
}

$h = fopen($file, 'rb');

if ($h === false) {
    exit("ERROR: No se pudo abrir el archivo.\n");
}

$headers = fgetcsv($h);
$index = array_flip($headers);

$required = ['clasificacion', 'motivo', 'periodo', 'programa'];

foreach ($required as $column) {
    if (!isset($index[$column])) {
        fclose($h);
        exit("ERROR: Falta columna: {$column}\n");
    }
}

$motivos = [];
$periodos = [];
$programas = [];
$combinaciones = [];
$total = 0;

while (($row = fgetcsv($h)) !== false) {

    $estado = $row[$index['clasificacion']] ?? '';

    if ($estado !== 'MATRICULA_PENDIENTE') {
        continue;
    }

    $total++;

    $motivo = $row[$index['motivo']] ?? '';
    $periodo = $row[$index['periodo']] ?? '';
    $programa = $row[$index['programa']] ?? '';

    $motivos[$motivo] = ($motivos[$motivo] ?? 0) + 1;
    $periodos[$periodo] = ($periodos[$periodo] ?? 0) + 1;
    $programas[$programa] = ($programas[$programa] ?? 0) + 1;

    $clave = $programa . ' | ' . $periodo;

    $combinaciones[$clave] =
        ($combinaciones[$clave] ?? 0) + 1;
}

fclose($h);

arsort($motivos);
arsort($periodos);
arsort($programas);
arsort($combinaciones);

echo "ORION v0.11.34 - DIAGNOSTICO DE PENDIENTES\n";
echo "=========================================\n";
echo "TOTAL MATRICULAS PENDIENTES: {$total}\n";

foreach ([
    'MOTIVOS' => $motivos,
    'PERIODOS' => $periodos,
    'PROGRAMAS' => $programas,
    'PROGRAMA + PERIODO' => $combinaciones
] as $titulo => $datos) {

    echo "\n=== {$titulo} ===\n";

    foreach (array_slice($datos, 0, 20, true) as $nombre => $cantidad) {
        printf("%-75s %d\n", $nombre, $cantidad);
    }
}

echo "\nDiagnostico finalizado. No se modificaron datos.\n";
