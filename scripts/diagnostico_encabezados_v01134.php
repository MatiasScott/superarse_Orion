<?php
declare(strict_types=1);

/**
 * Orion v0.11.34
 * Diagnóstico de encabezados de Estudiantes.xlsx
 * SOLO LECTURA
 */

$root = dirname(__DIR__);
$archivo = $root . '/Estudiantes.xlsx';

if (!is_file($archivo)) {
    exit("ERROR: No existe Estudiantes.xlsx\n");
}

$zip = new ZipArchive();

if ($zip->open($archivo) !== true) {
    exit("ERROR: No se pudo abrir el Excel.\n");
}

$ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';

$sharedStrings = [];

$sharedXml = $zip->getFromName('xl/sharedStrings.xml');

if ($sharedXml !== false) {
    $xml = simplexml_load_string($sharedXml);

    if ($xml === false) {
        exit("ERROR: No se pudieron leer sharedStrings.\n");
    }

    $xml->registerXPathNamespace('x', $ns);

    foreach ($xml->xpath('//x:si') ?: [] as $si) {
        $si->registerXPathNamespace('x', $ns);

        $partes = [];

        foreach ($si->xpath('.//x:t') ?: [] as $texto) {
            $partes[] = (string) $texto;
        }

        $sharedStrings[] = implode('', $partes);
    }
}

$sheetXml = $zip->getFromName(
    'xl/worksheets/sheet1.xml'
);

if ($sheetXml === false) {
    exit("ERROR: No existe sheet1.xml.\n");
}

$sheet = simplexml_load_string($sheetXml);

if ($sheet === false) {
    exit("ERROR: No se pudo leer sheet1.xml.\n");
}

$sheet->registerXPathNamespace('x', $ns);

$celdas = $sheet->xpath(
    '//x:sheetData/x:row[@r="1"]/x:c'
) ?: [];

echo PHP_EOL;
echo "ORION v0.11.34 | ENCABEZADOS EXCEL\n";
echo "===================================\n";

foreach ($celdas as $celda) {
    $celda->registerXPathNamespace('x', $ns);

    $referencia = (string) $celda['r'];
    $tipo = (string) $celda['t'];

    $valorNodo = $celda->xpath('./x:v');
    $valor = isset($valorNodo[0])
        ? (string) $valorNodo[0]
        : '';

    if ($tipo === 's') {
        $valor = $sharedStrings[(int) $valor] ?? '';
    } elseif ($tipo === 'inlineStr') {
        $partes = [];

        foreach ($celda->xpath('.//x:t') ?: [] as $texto) {
            $partes[] = (string) $texto;
        }

        $valor = implode('', $partes);
    }

    echo $referencia . ' | ' . trim($valor) . PHP_EOL;
}

$zip->close();

echo PHP_EOL;
echo "FIN: No se modificó ningún dato.\n";
