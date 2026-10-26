<?php

declare(strict_types=1);

/**
 * ORION v0.11.35 - Fase 2H
 * Inspección estructural de archivos Q10.
 *
 * Solo lectura.
 * No modifica archivos Excel ni bases de datos.
 * No exporta nombres ni calificaciones.
 */

$base = dirname(__DIR__);
$root = $base . '/notas';

if (!is_dir($root)) {
    exit("ERROR: No existe la carpeta notas.\n");
}

function leerSharedStrings(ZipArchive $zip): array
{
    $xml = $zip->getFromName('xl/sharedStrings.xml');

    if ($xml === false) {
        return [];
    }

    $doc = simplexml_load_string($xml);

    if ($doc === false) {
        return [];
    }

    $ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
    $doc->registerXPathNamespace('x', $ns);

    $strings = [];

    foreach ($doc->xpath('//x:si') ?: [] as $item) {
        $item->registerXPathNamespace('x', $ns);

        $parts = [];

        foreach ($item->xpath('.//x:t') ?: [] as $t) {
            $parts[] = (string)$t;
        }

        $strings[] = implode('', $parts);
    }

    return $strings;
}

function leerCeldas(
    ZipArchive $zip,
    array $shared,
    int $maxRows = 40
): array {
    $xml = $zip->getFromName('xl/worksheets/sheet1.xml');

    if ($xml === false) {
        return [];
    }

    $doc = simplexml_load_string($xml);

    if ($doc === false) {
        return [];
    }

    $ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
    $doc->registerXPathNamespace('x', $ns);

    $rows = [];

    foreach ($doc->xpath('//x:sheetData/x:row') ?: [] as $row) {
        $row->registerXPathNamespace('x', $ns);

        $rowNumber = (int)$row['r'];

        if ($rowNumber > $maxRows) {
            break;
        }

        foreach ($row->xpath('./x:c') ?: [] as $cell) {
            $cell->registerXPathNamespace('x', $ns);

            $coordinate = (string)$cell['r'];
            $type = (string)$cell['t'];

            $values = $cell->xpath('./x:v') ?: [];
            $inline = $cell->xpath('./x:is//x:t') ?: [];

            $value = '';

            if ($type === 's' && $values !== []) {
                $value = $shared[(int)$values[0]] ?? '';
            } elseif ($type === 'inlineStr') {
                foreach ($inline as $text) {
                    $value .= (string)$text;
                }
            } elseif ($values !== []) {
                $value = (string)$values[0];
            }

            $value = trim($value);

            if ($value !== '') {
                $rows[$rowNumber][$coordinate] = $value;
            }
        }
    }

    return $rows;
}

function normalizar(string $text): string
{
    $text = mb_strtolower(trim($text), 'UTF-8');

    $converted = iconv('UTF-8', 'ASCII//TRANSLIT//IGNORE', $text);

    if ($converted !== false) {
        $text = $converted;
    }

    return preg_replace('/\s+/', ' ', $text) ?? $text;
}

function detectarCabeceras(array $rows): array
{
    $patterns = [
        'identificacion' => '/cedula|identificacion|documento/',
        'estudiante' => '/estudiante|apellidos|nombres/',
        'parcial_1' => '/parcial\s*1|primer parcial/',
        'parcial_2' => '/parcial\s*2|segundo parcial/',
        'nota_final' => '/nota final|calificacion final|definitiva/',
        'supletorio' => '/supletorio|recuperacion/',
        'asistencia' => '/asistencia|inasistencia|faltas/'
    ];

    $found = [];

    foreach ($rows as $rowNumber => $cells) {
        foreach ($cells as $coordinate => $value) {
            $text = normalizar($value);

            foreach ($patterns as $field => $pattern) {
                if (preg_match($pattern, $text) === 1) {
                    $found[$field][] = $coordinate;
                }
            }
        }
    }

    return $found;
}

$iterator = new RecursiveIteratorIterator(
    new RecursiveDirectoryIterator(
        $root,
        FilesystemIterator::SKIP_DOTS
    )
);

$total = 0;
$detected = [];
$errors = 0;

foreach ($iterator as $file) {
    if (!$file->isFile() ||
        strtolower($file->getExtension()) !== 'xlsx') {
        continue;
    }

    $total++;

    $zip = new ZipArchive();

    if ($zip->open($file->getPathname()) !== true) {
        $errors++;
        continue;
    }

    $shared = leerSharedStrings($zip);
    $rows = leerCeldas($zip, $shared);
    $headers = detectarCabeceras($rows);

    foreach ($headers as $field => $coordinates) {
        $detected[$field] = ($detected[$field] ?? 0) + 1;
    }

    $zip->close();
}

echo "ORION v0.11.35 - DIAGNOSTICO DE CELDAS\n";
echo "======================================\n";
echo "Archivos inspeccionados: {$total}\n";
echo "Errores de apertura: {$errors}\n\n";

foreach ($detected as $field => $count) {
    echo "{$field}: {$count}\n";
}

echo "\nSolo lectura. Sin modificaciones.\n";
