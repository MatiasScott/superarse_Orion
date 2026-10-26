<?php

declare(strict_types=1);

$base = dirname(__DIR__);
$csv = $base . '/storage/import/historico_q10/notas_cursos.csv';
$notasDir = $base . '/NOTAS';

function normalizar(string $valor): string
{
    $valor = trim($valor);

    $valor = iconv('UTF-8', 'ASCII//TRANSLIT//IGNORE', $valor)
        ?: $valor;

    $valor = strtoupper($valor);
    $valor = preg_replace('/[^A-Z0-9]+/', ' ', $valor);

    return trim(preg_replace('/\s+/', ' ', $valor));
}

function segmentos(string $ruta): array
{
    $ruta = str_replace('\\', '/', $ruta);
    $partes = explode('/', $ruta);

    if (strtoupper($partes[0] ?? '') === 'NOTAS') {
        array_shift($partes);
    }

    return array_map('normalizar', $partes);
}

$archivos = [];

$iterator = new RecursiveIteratorIterator(
    new RecursiveDirectoryIterator(
        $notasDir,
        FilesystemIterator::SKIP_DOTS
    )
);

foreach ($iterator as $file) {
    if (!$file->isFile()) continue;
    if (strtolower($file->getExtension()) !== 'xlsx') continue;

    $ruta = str_replace('\\', '/', $file->getPathname());
    $relativa = substr($ruta, strlen(str_replace('\\', '/', $base)) + 1);

    $archivos[] = [
        'ruta' => $relativa,
        'segmentos' => segmentos($relativa),
    ];
}

$h = fopen($csv, 'rb');
$headers = fgetcsv($h);

$headers = array_map(
    fn($v) => preg_replace('/^\xEF\xBB\xBF/', '', $v),
    $headers
);

$resultados = [
    'total' => 0,
    'coincidencia_unica' => 0,
    'coincidencia_ambigua' => 0,
    'sin_coincidencia' => 0,
];

$archivosVinculados = [];

$ejemplos = [];

while (($data = fgetcsv($h)) !== false) {
    if (count($data) !== count($headers)) continue;

    $row = array_combine($headers, $data);
    $resultados['total']++;

    $objetivo = segmentos($row['file']);
    $coincidencias = [];

    foreach ($archivos as $archivo) {
        $actual = $archivo['segmentos'];

        if (count($actual) !== count($objetivo)) continue;

        $iguales = true;

        foreach ($objetivo as $i => $segmento) {
            $actualSegmento = $actual[$i];

            // Se permite un prefijo numérico en el período.
            if ($i === 0) {
                $actualSegmento = preg_replace(
                    '/^\d+\s+/',
                    '',
                    $actualSegmento
                );
            }

            if ($segmento !== $actualSegmento) {
                $iguales = false;
                break;
            }
        }

        if ($iguales) {
            $coincidencias[] = $archivo['ruta'];
        }
    }

    if (count($coincidencias) === 1) {
        $resultados['coincidencia_unica']++;
        $archivosVinculados[$coincidencias[0]] = true;
    } elseif (count($coincidencias) > 1) {
        $resultados['coincidencia_ambigua']++;
    } else {
        $resultados['sin_coincidencia']++;

        if (count($ejemplos) < 10) {
            $ejemplos[] = [
                'curso' => $row['course_id'],
                'ruta' => $row['file'],
            ];
        }
    }
}

fclose($h);

echo "\n=== CONCILIACIÓN DE RUTAS Q10 v0.11.35 ===\n";

foreach ($resultados as $clave => $valor) {
    echo str_pad($clave, 25) . ": $valor\n";
}

echo "\n=== EJEMPLOS SIN COINCIDENCIA ===\n";

foreach ($ejemplos as $ejemplo) {
    echo "Curso {$ejemplo['curso']}: {$ejemplo['ruta']}\n";
}

echo "\nDiagnóstico finalizado. Solo lectura.\n";
$pendientes = [];

foreach ($archivos as $archivo) {
    if (!isset($archivosVinculados[$archivo['ruta']])) {
        $pendientes[] = $archivo['ruta'];
    }
}

echo "\n=== COBERTURA DE EXCEL Q10 ===\n";
echo "Excel originales: " . count($archivos) . "\n";
echo "Excel vinculados: " . count($archivosVinculados) . "\n";
echo "Excel pendientes: " . count($pendientes) . "\n";

echo "\n=== PRIMEROS 15 ARCHIVOS PENDIENTES ===\n";

foreach (array_slice($pendientes, 0, 15) as $ruta) {
    echo $ruta . "\n";
}

echo "\n=== ANÁLISIS DE DUPLICADOS SHA-256 ===\n";

$hashes = [];
$duplicados = 0;
$unicos = 0;
$errores = 0;

foreach ($pendientes as $ruta) {
    $archivo = $base . '/' . $ruta;

    $hash = hash_file('sha256', $archivo);

    if ($hash === false) {
        $errores++;
        continue;
    }

    if (isset($hashes[$hash])) {
        $duplicados++;
    } else {
        $hashes[$hash] = $ruta;
        $unicos++;
    }
}

echo "Excel pendientes: " . count($pendientes) . "\n";
echo "Contenido único entre pendientes: $unicos\n";
echo "Copias idénticas entre pendientes: $duplicados\n";
echo "Errores de lectura: $errores\n";

echo "\n=== EJEMPLOS DE DUPLICADOS ===\n";

$mostrados = 0;
$vistos = [];

foreach ($pendientes as $ruta) {
    $hash = hash_file('sha256', $base . '/' . $ruta);

    if ($hash === false) {
        continue;
    }

    if (isset($vistos[$hash]) && $mostrados < 10) {
        echo "\nOriginal: {$vistos[$hash]}\n";
        echo "Copia:    $ruta\n";
        $mostrados++;
    } else {
        $vistos[$hash] ??= $ruta;
    }
}