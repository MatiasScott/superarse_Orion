<?php

declare(strict_types=1);

/**
 * Orion v0.11.35 - Fase 2G
 * Inventario de archivos de calificaciones Q10.
 *
 * SOLO LECTURA de los Excel.
 * Genera reportes CSV locales.
 * No modifica MySQL, Moodle ni Microsoft 365.
 */

$base = dirname(__DIR__);
$root = $base . '/notas';
$output = $base . '/storage/conciliacion/v01135';

if (!is_dir($root)) {
    exit("ERROR: No existe la carpeta notas.\n");
}

if (!is_dir($output) &&
    !mkdir($output, 0700, true) &&
    !is_dir($output)) {
    exit("ERROR: No se pudo crear el directorio de reportes.\n");
}

$csvPath = $output . '/inventario_archivos.csv';
$csv = fopen($csvPath, 'wb');

if (!$csv) {
    exit("ERROR: No se pudo crear el reporte.\n");
}

fputcsv($csv, [
    'periodo_numero',
    'periodo_carpeta',
    'programa_carpeta',
    'asignatura_carpeta',
    'archivo',
    'extension',
    'tamano_bytes',
    'sha256'
]);

$stats = [];
$extensions = [];
$errors = [];
$total = 0;

$iterator = new RecursiveIteratorIterator(
    new RecursiveDirectoryIterator(
        $root,
        FilesystemIterator::SKIP_DOTS
    )
);

foreach ($iterator as $file) {

    if (!$file->isFile()) {
        continue;
    }

    $extension = strtolower($file->getExtension());

    if (!in_array($extension, ['xlsx', 'xls'], true)) {
        continue;
    }

    $relative = substr(
        $file->getPathname(),
        strlen($root) + 1
    );

    $parts = preg_split('~[/\\\\]+~', $relative);

    $periodFolder = $parts[0] ?? '';
    $programFolder = $parts[1] ?? '';
    $subjectFolder = count($parts) >= 4
        ? implode('/', array_slice($parts, 2, -1))
        : '';

    $periodNumber = '';

    if (preg_match('/^(\d+)\./', $periodFolder, $matches)) {
        $periodNumber = $matches[1];
    }

    $hash = hash_file('sha256', $file->getPathname());

    if ($hash === false) {
        $errors[] = $relative;
        continue;
    }

    fputcsv($csv, [
        $periodNumber,
        $periodFolder,
        $programFolder,
        $subjectFolder,
        $file->getFilename(),
        $extension,
        $file->getSize(),
        $hash
    ]);

    $total++;

    $stats[$periodFolder] =
        ($stats[$periodFolder] ?? 0) + 1;

    $extensions[$extension] =
        ($extensions[$extension] ?? 0) + 1;
}

fclose($csv);
@chmod($csvPath, 0600);

uksort($stats, static function ($a, $b) {
    preg_match('/^\d+/', $a, $ma);
    preg_match('/^\d+/', $b, $mb);

    return ((int)($ma[0] ?? 0))
        <=> ((int)($mb[0] ?? 0));
});

echo "ORION v0.11.35 - INVENTARIO Q10\n";
echo "================================\n";
echo "Total archivos: {$total}\n\n";

foreach ($stats as $period => $count) {
    echo "{$period}: {$count}\n";
}

echo "\nEXTENSIONES\n";

foreach ($extensions as $ext => $count) {
    echo "{$ext}: {$count}\n";
}

echo "\nErrores de lectura: " . count($errors) . "\n";
echo "Reporte: {$csvPath}\n";
echo "No se modificaron datos academicos.\n";
