<?php

declare(strict_types=1);

/**
 * ORION v0.11.35 - Fase 2G
 * Diagnóstico de formatos de notas Q10.
 *
 * Solo lectura de XLSX.
 * No modifica bases de datos ni archivos originales.
 */

$base = dirname(__DIR__);
$root = $base . '/notas';
$output = $base . '/storage/conciliacion/v01135';

if (!is_dir($root)) {
    exit("ERROR: No existe la carpeta notas.\n");
}

if (!is_dir($output) && !mkdir($output, 0700, true)) {
    exit("ERROR: No se pudo crear el directorio de salida.\n");
}

function normalizarTexto(string $value): string
{
    $value = trim($value);
    $value = mb_strtolower($value, 'UTF-8');
    $value = preg_replace('/\s+/u', ' ', $value) ?? $value;

    return $value;
}


function leerCadenasCompartidas(ZipArchive $zip): array
{
    $xml = $zip->getFromName('xl/sharedStrings.xml');

    if ($xml === false) {
        return [];
    }

    $document = simplexml_load_string($xml);

    if ($document === false) {
        return [];
    }

    $ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';

    $document->registerXPathNamespace('x', $ns);

    $result = [];

    foreach ($document->xpath('//x:si') ?: [] as $item) {

        // Cada nodo necesita registrar el namespace.
        $item->registerXPathNamespace('x', $ns);

        $parts = [];

        foreach ($item->xpath('.//x:t') ?: [] as $text) {
            $parts[] = (string)$text;
        }

        $result[] = implode('', $parts);
    }

    return $result;
}



function leerPrimerasFilas(
    ZipArchive $zip,
    string $sheetPath,
    array $sharedStrings,
    int $limit = 15
): array {

    $xml = $zip->getFromName($sheetPath);

    if ($xml === false) {
        return [];
    }

    $document = simplexml_load_string($xml);

    if ($document === false) {
        return [];
    }

    $ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';

    $document->registerXPathNamespace('x', $ns);

    $rows = [];

    foreach ($document->xpath('//x:sheetData/x:row') ?: [] as $row) {

        $row->registerXPathNamespace('x', $ns);

        $cells = [];

        foreach ($row->xpath('./x:c') ?: [] as $cell) {

            $cell->registerXPathNamespace('x', $ns);

            $type = (string)$cell['t'];

            $value = $cell->xpath('./x:v') ?: [];
            $inline = $cell->xpath('./x:is//x:t') ?: [];

            $content = '';

            if ($type === 's' && !empty($value)) {

                $index = (int)$value[0];

                $content = $sharedStrings[$index] ?? '';
            } elseif ($type === 'inlineStr' && !empty($inline)) {

                $content = implode(
                    '',
                    array_map(
                        static fn($v) => (string)$v,
                        $inline
                    )
                );
            } elseif (!empty($value)) {

                $content = (string)$value[0];
            }

            $content = trim($content);

            if ($content !== '') {
                $cells[] = $content;
            }
        }

        if ($cells !== []) {
            $rows[] = $cells;
        }

        if (count($rows) >= $limit) {
            break;
        }
    }

    return $rows;
}



function detectarFilaCabecera(array $rows): array
{
    $keywords = [
        'estudiante',
        'apellidos',
        'apellido',
        'nombres',
        'nombre',
        'identificacion',
        'cedula',
        'calificacion',
        'nota final',
        'definitiva',
        'parcial 1',
        'parcial 2',
        'primer parcial',
        'segundo parcial',
        'supletorio'
    ];

    $bestRow = -1;
    $bestScore = 0;
    $bestCells = [];

    foreach ($rows as $index => $cells) {
        $score = 0;

        foreach ($cells as $cell) {
            $normalized = normalizarTexto($cell);

            foreach ($keywords as $keyword) {
                if (str_contains($normalized, $keyword)) {
                    $score++;
                    break;
                }
            }
        }

        if ($score > $bestScore) {
            $bestScore = $score;
            $bestRow = $index;
            $bestCells = $cells;
        }
    }

    return [
        'fila_indice' => $bestRow,
        'puntaje' => $bestScore,
        'cabeceras' => $bestCells
    ];
}


function detectarFormato(array $rows): array
{
    $text = normalizarTexto(
        implode(' ', array_merge(...($rows ?: [[]])))
    );

    $signals = [
        'parcial_1' => preg_match('/parcial\s*1|primer parcial/u', $text) === 1,
        'parcial_2' => preg_match('/parcial\s*2|segundo parcial/u', $text) === 1,
        'nota_final' => preg_match('/nota final|calificaci[oó]n final|definitiva/u', $text) === 1,
        'supletorio' => preg_match('/supletorio|recuperaci[oó]n/u', $text) === 1,
        'inasistencias' => preg_match('/inasistencia|falta|asistencia/u', $text) === 1,
    ];

    if ($signals['parcial_1'] && $signals['parcial_2']) {
        $format = 'PARCIALES';
    } elseif ($signals['nota_final']) {
        $format = 'NOTA_FINAL';
    } else {
        $format = 'POR_REVISAR';
    }

    return [$format, $signals];
}

$detailPath = $output . '/diagnostico_formatos.csv';
$summaryPath = $output . '/resumen_formatos.csv';

$detail = fopen($detailPath, 'wb');

if ($detail === false) {
    exit("ERROR: No se pudo crear el reporte.\n");
}

fputcsv($detail, [
    'periodo',
    'archivo_relativo',
    'hoja',
    'formato_detectado',
    'parcial_1',
    'parcial_2',
    'nota_final',
    'supletorio',
    'inasistencias',
    'muestra_cabeceras',
    'error'
]);

$summary = [];
$total = 0;
$errors = 0;

$iterator = new RecursiveIteratorIterator(
    new RecursiveDirectoryIterator(
        $root,
        FilesystemIterator::SKIP_DOTS
    )
);

foreach ($iterator as $file) {
    if (
        !$file->isFile() ||
        strtolower($file->getExtension()) !== 'xlsx'
    ) {
        continue;
    }

    $total++;

    $relative = substr(
        $file->getPathname(),
        strlen($root) + 1
    );

    $parts = preg_split('~[/\\\\]+~', $relative);
    $period = $parts[0] ?? '';

    $zip = new ZipArchive();

    if ($zip->open($file->getPathname()) !== true) {
        $errors++;
        fputcsv($detail, [
            $period,
            $relative,
            '',
            'ERROR',
            0,
            0,
            0,
            0,
            0,
            '',
            'No se pudo abrir XLSX'
        ]);
        continue;
    }

    $shared = leerCadenasCompartidas($zip);

    // En esta primera fase inspeccionamos la primera hoja.
    $sheetPath = 'xl/worksheets/sheet1.xml';

    $rows = leerPrimerasFilas($zip, $sheetPath, $shared);

    if ($rows === []) {
        $errors++;
        fputcsv($detail, [
            $period,
            $relative,
            'sheet1',
            'ERROR',
            0,
            0,
            0,
            0,
            0,
            '',
            'Hoja vacia o no localizada'
        ]);
        $zip->close();
        continue;
    }

    [$format, $signals] = detectarFormato($rows);

    $headerInfo = detectarFilaCabecera($rows);

    $summary[$format] = ($summary[$format] ?? 0) + 1;

    // Solo etiquetas de la primera fila no vacía.
    // No exportar datos de estudiantes al diagnóstico.
    $sample = $headerInfo['puntaje'] >= 2
        ? implode(' | ', array_slice($headerInfo['cabeceras'], 0, 20))
        : 'CABECERA_NO_CONFIRMADA';

    fputcsv($detail, [
        $period,
        $relative,
        'sheet1',
        $format,
        (int)$signals['parcial_1'],
        (int)$signals['parcial_2'],
        (int)$signals['nota_final'],
        (int)$signals['supletorio'],
        (int)$signals['inasistencias'],
        $sample,
        ''
    ]);

    $zip->close();
}

fclose($detail);

$summaryFile = fopen($summaryPath, 'wb');

if ($summaryFile !== false) {
    fputcsv($summaryFile, ['formato', 'cantidad']);

    foreach ($summary as $format => $count) {
        fputcsv($summaryFile, [$format, $count]);
    }

    fclose($summaryFile);
}

@chmod($detailPath, 0600);
@chmod($summaryPath, 0600);

echo "ORION v0.11.35 - FORMATOS Q10\n";
echo "================================\n";
echo "Archivos inspeccionados: {$total}\n";

foreach ($summary as $format => $count) {
    echo "{$format}: {$count}\n";
}

echo "Errores: {$errors}\n";
echo "Detalle: {$detailPath}\n";
echo "Resumen: {$summaryPath}\n";
echo "Sin modificaciones a la base de datos.\n";
