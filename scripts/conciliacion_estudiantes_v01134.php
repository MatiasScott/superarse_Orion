<?php

declare(strict_types=1);
/** Orion v0.11.34 - Fase 2F. Diagnostico de conciliacion. SOLO SELECT + CSV locales. */
require dirname(__DIR__) . '/vendor/autoload.php';

use App\Core\Config;
use App\Core\Database;
use Dotenv\Dotenv;

$base = dirname(__DIR__);
Dotenv::createImmutable($base)->safeLoad();
$path = $argv[1] ?? $base . '/Estudiantes.xlsx';
if (!is_file($path)) throw new RuntimeException("No existe el archivo: $path");
$zip = new ZipArchive();
if ($zip->open($path) !== true) throw new RuntimeException('No se pudo abrir XLSX');
$ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
$shared = [];
$ss = $zip->getFromName('xl/sharedStrings.xml');
if ($ss !== false) {
    $xml = new SimpleXMLElement($ss);
    foreach ($xml->children($ns)->si as $si) {
        $txt = '';
        foreach ($si->xpath('.//*[local-name()="t"]') ?: [] as $t) $txt .= (string)$t;
        $shared[] = $txt;
    }
}
$sheet = $zip->getFromName('xl/worksheets/sheet1.xml');
if ($sheet === false) throw new RuntimeException('No se encontro hoja 1');
$doc = new SimpleXMLElement($sheet);
$rows = $doc->xpath('//*[local-name()="sheetData"]/*[local-name()="row"]');
if (!$rows) throw new RuntimeException('La hoja esta vacia');
function v34Col(string $ref): int
{
    $letters = preg_replace('/\d+/', '', strtoupper($ref));
    $n = 0;
    foreach (str_split($letters) as $c) $n = $n * 26 + ord($c) - 64;
    return $n - 1;
}
function v34Row(SimpleXMLElement $row, array $shared): array
{
    $out = [];
    foreach ($row->xpath('./*[local-name()="c"]') ?: [] as $c) {
        $a = $c->attributes();
        $typ = (string)$a['t'];
        $v = $c->xpath('./*[local-name()="v"]');
        $val = $v ? (string)$v[0] : '';
        if ($typ === 's') $val = $shared[(int)$val] ?? '';
        elseif ($typ === 'inlineStr') $val = implode('', array_map('strval', $c->xpath('.//*[local-name()="t"]') ?: []));
        $out[v34Col((string)$a['r'])] = trim($val);
    }
    return $out;
}
function v34Norm(string $v): string
{
    $v = mb_strtoupper(trim($v), 'UTF-8');
    $v = strtr($v, ['Á' => 'A', 'É' => 'E', 'Í' => 'I', 'Ó' => 'O', 'Ú' => 'U', 'Ü' => 'U', 'Ñ' => 'N']);
    return preg_replace('/\s+/u', ' ', $v) ?? $v;
}
$headers = v34Row($rows[0], $shared);
$index = [];
foreach ($headers as $i => $h) $index[v34Norm($h)] = $i;
function v34Field(array $r, array $index, string $name): string
{
    return (string)($r[$index[v34Norm($name)] ?? -1] ?? '');
}
foreach (['Código de matrícula', 'Número de identificación', 'Programa', 'Sede', 'Período', 'Nivel', 'Estado'] as $required) {
    if (!array_key_exists(v34Norm($required), $index)) throw new RuntimeException("Falta columna: $required");
}
$db = (new Database(new Config($_ENV)))->connection();
$db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

$people = [];
foreach ($db->query('SELECT p.id AS persona_id,p.numero_identificacion,e.id AS estudiante_id FROM personas p LEFT JOIN estudiantes e ON e.persona_id=p.id AND e.deleted_at IS NULL WHERE p.deleted_at IS NULL') as $r) {
    $id = trim((string)$r['numero_identificacion']);
    if ($id !== '') $people[$id][] = ['persona_id' => (int)$r['persona_id'], 'estudiante_id' => $r['estudiante_id'] === null ? null : (int)$r['estudiante_id']];
}
$programs = [];
foreach ($db->query('SELECT id,q10_programa_nombre,carrera_id,sede_id FROM migracion_q10_programas') as $r) {
    $key = v34Norm((string)$r['q10_programa_nombre']);
    $programs[$key][] = ['map_id' => (int)$r['id'], 'carrera_id' => (int)$r['carrera_id'], 'sede_id' => (int)$r['sede_id']];
}
$sedes = [];
foreach ($db->query('SELECT id,nombre FROM sedes WHERE deleted_at IS NULL') as $r) {
    $sedes[v34Norm((string)$r['nombre'])][] = (int)$r['id'];
}
$periods = [];
foreach ($db->query('SELECT id,nombre,codigo FROM periodos_academicos WHERE deleted_at IS NULL') as $r) {
    foreach ([(string)$r['nombre'], (string)$r['codigo']] as $s) {
        $key = v34Norm($s);
        if ($key !== '') $periods[$key][(int)$r['id']] = true;
    }
}
$trajs = [];
foreach ($db->query('SELECT id,estudiante_id,carrera_id,malla_id,sede_id FROM estudiante_carreras WHERE deleted_at IS NULL') as $r) {
    $trajs[(int)$r['estudiante_id']][] = [
        'id' => (int)$r['id'],
        'carrera_id' => (int)$r['carrera_id'],
        'malla_id' => (int)$r['malla_id'],
        'sede_id' => $r['sede_id'] === null ? null : (int)$r['sede_id']
    ];
}
$enrollments = [];
$byNumber = [];
foreach ($db->query('SELECT id,numero_matricula,estudiante_carrera_id,periodo_academico_id FROM matriculas WHERE activo = 1') as $r) {
    $m = [
        'id' => (int)$r['id'],
        'numero_matricula' => (string)$r['numero_matricula'],
        'trayectoria_id' => (int)$r['estudiante_carrera_id'],
        'periodo_id' => (int)$r['periodo_academico_id']
    ];
    $enrollments[$m['trayectoria_id']][$m['periodo_id']][] = $m;
    $byNumber[$m['numero_matricula']][] = $m;
}
$outDir = $base . '/storage/conciliacion/v01134';
if (!is_dir($outDir) && !mkdir($outDir, 0700, true) && !is_dir($outDir)) throw new RuntimeException('No se pudo crear carpeta');
function v34Csv(string $file, array $headers, array $rows): void
{
    $h = fopen($file, 'wb');
    if (!$h) throw new RuntimeException("No se pudo crear $file");
    fputcsv($h, $headers);
    foreach ($rows as $r) {
        $safe = array_map(static function ($v): string {
            $s = (string)$v;
            return preg_match('/^[\s]*[=+@\-\t\r]/u', $s) ? "'" . $s : $s;
        }, $r);
        fputcsv($h, $safe);
    }
    fclose($h);
    @chmod($file, 0600);
}
$detail = [];
$summary = [];
$seen = [];
foreach (array_slice($rows, 1) as $row) {
    $r = v34Row($row, $shared);
    if (!array_filter($r, static fn($v) => $v !== '')) continue;
    $line = (int)$row->attributes()['r'];
    $id = trim(v34Field($r, $index, 'Número de identificación'));
    $program = v34Norm(v34Field($r, $index, 'Programa'));
    $sede = v34Norm(v34Field($r, $index, 'Sede'));
    $period = v34Norm(v34Field($r, $index, 'Período'));
    $level = v34Norm(v34Field($r, $index, 'Nivel'));
    $status = v34Norm(v34Field($r, $index, 'Estado'));
    $excelNumber = trim(v34Field($r, $index, 'Código de matrícula'));
    $personRows = $people[$id] ?? [];
    $maps = $programs[$program] ?? [];
    $periodIds = array_keys($periods[$period] ?? []);
    $class = '';
    $reason = '';
    $studentId = null;
    $trajIds = [];
    $enrollmentIds = [];
    $careerId = null;
    $mappedSedeId = null;
    if ($id === '') {
        $class = 'IDENTIFICACION_VACIA';
        $reason = 'No hay identificacion';
    } elseif (count($personRows) === 0) {
        $class = 'PERSONA_NUEVA';
        $reason = 'No existe persona en Orion';
    } elseif (count($personRows) > 1) {
        $class = 'PERSONA_AMBIGUA';
        $reason = 'Multiples personas con la identificacion';
    } elseif ($personRows[0]['estudiante_id'] === null) {
        $class = 'EXPEDIENTE_PENDIENTE';
        $reason = 'Persona existente sin estudiante activo';
    } elseif (count($maps) === 0) {
        $class = 'PROGRAMA_PENDIENTE';
        $reason = 'Programa sin equivalencia exacta Q10';
    } elseif (count($maps) > 1) {
        $class = 'PROGRAMA_AMBIGUO';
        $reason = 'Varias equivalencias Q10';
    } else {
        $studentId = $personRows[0]['estudiante_id'];
        $careerId = $maps[0]['carrera_id'];
        $mappedSedeId = $maps[0]['sede_id'];
        $sedeIds = array_values(array_unique($sedes[$sede] ?? []));
        // Sede vacia o sin equivalencia exacta: no se declara contradiccion.
        if ($sede !== '' && count($sedeIds) === 1 && $sedeIds[0] !== $mappedSedeId) {
            $class = 'SEDE_CONFLICTO';
            $reason = 'Sede Excel contradice sede del programa Q10';
        } elseif ($sede !== '' && count($sedeIds) > 1) {
            $class = 'SEDE_AMBIGUA';
            $reason = 'Sede Excel coincide con varias sedes';
        } else {
            foreach ($trajs[$studentId] ?? [] as $t) {
                if ($t['carrera_id'] !== $careerId) continue;
                if ($t['sede_id'] !== null && $t['sede_id'] !== $mappedSedeId) continue;
                $trajIds[] = $t['id'];
            }
            if (count($trajIds) === 0) {
                $class = 'TRAYECTORIA_PENDIENTE';
                $reason = 'Sin trayectoria compatible carrera y sede';
            } elseif (count($trajIds) > 1) {
                $class = 'TRAYECTORIA_AMBIGUA';
                $reason = 'Varias trayectorias compatibles; revisar mallas';
            } elseif (count($periodIds) === 0) {
                $class = 'PERIODO_PENDIENTE';
                $reason = 'Periodo sin equivalencia exacta en Orion';
            } elseif (count($periodIds) > 1) {
                $class = 'PERIODO_AMBIGUO';
                $reason = 'Periodo coincide con varios IDs';
            } else {
                $enrollmentsHere = $enrollments[$trajIds[0]][$periodIds[0]] ?? [];
                $enrollmentIds = array_column($enrollmentsHere, 'id');
                if (count($enrollmentsHere) === 1) {
                    $class = 'MATRICULA_EXISTENTE';
                    $reason = 'Coincide trayectoria y periodo (codigo Excel no validado como equivalente)';
                } elseif (count($enrollmentsHere) > 1) {
                    $class = 'MATRICULA_AMBIGUA';
                    $reason = 'Multiples matriculas en trayectoria y periodo';
                } else {
                    $class = 'MATRICULA_PENDIENTE';
                    $reason = 'Sin matricula para trayectoria y periodo';
                }
            }
        }
    }
    // Codigo Excel: detectar colisiones exactas sin asumir equivalencia con Q10H.
    if ($excelNumber !== '' && isset($byNumber[$excelNumber])) {
        $reason .= '; codigo Excel aparece en Orion, verificar titularidad';
    }
    $summary[$class] = ($summary[$class] ?? 0) + 1;
    if ($id !== '') $seen[$id] = true;
    $masked = $id === '' ? '' : str_repeat('*', max(0, strlen($id) - 4)) . substr($id, -4);
    $detail[] = [
        $line,
        $masked,
        $program,
        $sede,
        $period,
        $level,
        $status,
        $class,
        $reason,
        $studentId ?? '',
        $careerId ?? '',
        $mappedSedeId ?? '',
        implode('|', $trajIds),
        implode('|', $periodIds),
        implode('|', $enrollmentIds),
        $excelNumber === '' ? 'NO' : 'SI'
    ];
}
$zip->close();
ksort($summary);
$header = ['fila_excel', 'identificacion_enmascarada', 'programa', 'sede', 'periodo', 'nivel', 'estado_excel', 'clasificacion', 'motivo', 'estudiante_id', 'carrera_id', 'sede_q10_id', 'trayectorias_ids', 'periodos_ids', 'matriculas_ids', 'codigo_matricula_excel_presente'];
v34Csv($outDir . '/detalle_conciliacion.csv', $header, $detail);
v34Csv($outDir . '/resumen.csv', ['clasificacion', 'filas'], array_map(static fn($k, $v) => [$k, $v], array_keys($summary), array_values($summary)));
echo "ORION v0.11.34 | FASE 2F | SOLO LECTURA\n";
echo 'Filas analizadas: ' . count($detail) . "\n";
echo 'Identificaciones unicas: ' . count($seen) . "\n";
foreach ($summary as $k => $v) printf("%-30s %d\n", $k, $v);
echo "Reportes: $outDir\nNo se modifico MySQL, Moodle ni Microsoft 365.\n";
