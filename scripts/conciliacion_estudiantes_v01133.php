<?php
declare(strict_types=1);
/** Orion v0.11.33 Fase 2E: diagnóstico de estudiantes. Solo SELECT + CSV locales. */
require dirname(__DIR__) . '/vendor/autoload.php';
use App\Core\Config;
use App\Core\Database;
use Dotenv\Dotenv;
Dotenv::createImmutable(dirname(__DIR__))->safeLoad();
$path = $argv[1] ?? dirname(__DIR__) . '/Estudiantes.xlsx';
if (!is_file($path)) { fwrite(STDERR, "No existe el archivo Excel: $path\n"); exit(1); }
if (!class_exists(ZipArchive::class)) { fwrite(STDERR, "Habilita extension PHP zip\n"); exit(1); }
$zip = new ZipArchive();
if ($zip->open($path) !== true) throw new RuntimeException('No se pudo abrir XLSX');
$ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
$shared = [];
$ss = $zip->getFromName('xl/sharedStrings.xml');
if ($ss !== false) {
    $xml = new SimpleXMLElement($ss);
    foreach ($xml->children($ns)->si as $si) {
        $txt = '';
        foreach ($si->xpath('.//*[local-name()="t"]') as $t) $txt .= (string)$t;
        $shared[] = $txt;
    }
}
$sheet = $zip->getFromName('xl/worksheets/sheet1.xml');
if ($sheet === false) throw new RuntimeException('No se encontro hoja 1');
$doc = new SimpleXMLElement($sheet);
$rows = $doc->xpath('//*[local-name()="sheetData"]/*[local-name()="row"]');
if (!$rows) throw new RuntimeException('La hoja esta vacia');
function cidx(string $ref): int { $letters = preg_replace('/\d+/', '', strtoupper($ref)); $n = 0; foreach (str_split($letters) as $c) $n = $n * 26 + ord($c) - 64; return $n - 1; }
function prow(SimpleXMLElement $row, array $shared): array {
    $out = [];
    foreach ($row->xpath('./*[local-name()="c"]') as $c) {
        $a = $c->attributes(); $ref = (string)$a['r']; $typ = (string)$a['t'];
        $v = $c->xpath('./*[local-name()="v"]'); $val = $v ? (string)$v[0] : '';
        if ($typ === 's') $val = $shared[(int)$val] ?? '';
        if ($typ === 'inlineStr') $val = implode('', array_map('strval', $c->xpath('.//*[local-name()="t"]')));
        $out[cidx($ref)] = trim($val);
    }
    return $out;
}
function normv(string $v): string { $v = mb_strtoupper(trim($v), 'UTF-8'); $v = strtr($v, ['Á'=>'A','É'=>'E','Í'=>'I','Ó'=>'O','Ú'=>'U','Ü'=>'U','Ñ'=>'N']); return preg_replace('/\s+/u', ' ', $v); }
$headers = prow($rows[0], $shared); $index = [];
foreach ($headers as $i => $h) $index[normv($h)] = $i;
function fld(array $r, array $index, string $name): string { return (string)($r[$index[normv($name)] ?? -1] ?? ''); }
foreach (['Número de identificación', 'Programa', 'Nivel', 'Estado', 'Período'] as $required) {
    if (!array_key_exists(normv($required), $index)) throw new RuntimeException("Falta columna obligatoria: $required");
}
$db = (new Database(new Config($_ENV)))->connection();
$persons = [];
foreach ($db->query('SELECT numero_identificacion FROM personas WHERE deleted_at IS NULL') as $p) {
    $key = trim((string)$p['numero_identificacion']); if ($key !== '') $persons[$key] = true;
}
$programs = [];
foreach ($db->query('SELECT nombre FROM carreras WHERE activo=1 AND deleted_at IS NULL') as $p) $programs[normv((string)$p['nombre'])] = true;
$levels = [];
foreach ($db->query('SELECT codigo,nombre FROM niveles_academicos WHERE activo=1') as $l) {
    $levels[normv((string)$l['codigo'])] = true; $levels[normv((string)$l['nombre'])] = true;
}
$knownStatuses = array_fill_keys(['ACTIVO','INACTIVO','CANCELADO','GRADUADO','EGRESADO'], true);
$records = []; $groups = []; $unknownPrograms = []; $unknownLevels = []; $unknownStatuses = []; $periods = []; $missingLevels = []; $statusIssues = [];
$total = 0; $existingRows = 0; $newRows = 0; $emptyIds = 0; $scholarship = 0; $income = 0;
foreach (array_slice($rows, 1) as $row) {
    $r = prow($row, $shared);
    if (!array_filter($r, static fn($v) => $v !== '')) continue;
    $total++; $rowNum = (int)$row->attributes()['r'];
    $id = trim(fld($r, $index, 'Número de identificación'));
    $program = normv(fld($r, $index, 'Programa'));
    $level = normv(fld($r, $index, 'Nivel'));
    $status = normv(fld($r, $index, 'Estado'));
    $period = normv(fld($r, $index, 'Período'));
    $isExisting = $id !== '' && isset($persons[$id]);
    if ($id === '') $emptyIds++; elseif ($isExisting) $existingRows++; else $newRows++;
    if (in_array(normv(fld($r, $index, 'Tiene Beca')), ['SI','YES','1'], true)) $scholarship++;
    if (fld($r, $index, 'Ingresos del Hogar') !== '') $income++;
    $rec = ['fila'=>$rowNum,'programa'=>$program,'nivel'=>$level,'estado'=>$status,'periodo'=>$period];
    if ($id !== '') $groups[$id][] = $rec;
    if ($program === '' || !isset($programs[$program])) $unknownPrograms[$program === '' ? '(VACIO)' : $program][] = $rowNum;
    if ($level === '') $missingLevels[] = $rec;
    elseif (!isset($levels[$level])) $unknownLevels[$level][] = $rowNum;
    if ($status === '' || !isset($knownStatuses[$status])) {
        $unknownStatuses[$status === '' ? '(VACIO)' : $status] = ($unknownStatuses[$status === '' ? '(VACIO)' : $status] ?? 0) + 1;
        $statusIssues[] = $rec;
    }
    $periods[$period === '' ? '(VACIO)' : $period] = ($periods[$period === '' ? '(VACIO)' : $period] ?? 0) + 1;
}
$zip->close();
$outDir = dirname(__DIR__) . '/storage/conciliacion/v01133';
if (!is_dir($outDir) && !mkdir($outDir, 0700, true) && !is_dir($outDir)) throw new RuntimeException('No se pudo crear carpeta de reportes');
function report(string $dir, string $name, array $headers, array $rows): void {
    $file = $dir . '/' . $name;
    $h = fopen($file, 'wb'); if (!$h) throw new RuntimeException("No se pudo crear $file");
    fputcsv($h, $headers);
    foreach ($rows as $r) {
        $safe = array_map(static function($v) { $s = (string)$v; return preg_match('/^[\s]*[=+@\-\t\r]/u', $s) ? "'".$s : $s; }, $r);
        fputcsv($h, $safe);
    }
    fclose($h); @chmod($file, 0600);
}
$progRows = [];
foreach ($unknownPrograms as $name => $nums) $progRows[] = [$name, count($nums), implode('|', array_slice($nums, 0, 100)), 'PENDIENTE'];
usort($progRows, static fn($a,$b) => $b[1] <=> $a[1]);
report($outDir, 'programas_pendientes.csv', ['programa_excel','filas','filas_ejemplo_max_100','decision_manual'], $progRows);
$dupRows = []; $duplicatedPersons = 0; $additional = 0; $multiProgram = 0; $multiPeriod = 0; $newUnique = 0; $existingUnique = 0;
foreach ($groups as $id => $items) {
    if (isset($persons[$id])) $existingUnique++; else $newUnique++;
    $n = count($items); if ($n < 2) continue;
    $duplicatedPersons++; $additional += $n-1;
    $ps = array_values(array_unique(array_column($items, 'programa')));
    $ts = array_values(array_unique(array_column($items, 'periodo')));
    if (count($ps) > 1) $multiProgram++;
    if (count($ts) > 1) $multiPeriod++;
    $mask = str_repeat('*', max(0, strlen($id)-4)) . substr($id, -4);
    $dupRows[] = [$mask, $n, implode('|', array_column($items, 'fila')), implode('|', $ps), implode('|', $ts), implode('|', array_unique(array_column($items, 'estado'))), count($ps)>1?'SI':'NO', count($ts)>1?'SI':'NO'];
}
report($outDir, 'identificaciones_repetidas.csv', ['identificacion_enmascarada','apariciones','filas','programas','periodos','estados','multiples_programas','multiples_periodos'], $dupRows);
report($outDir, 'niveles_pendientes.csv', ['fila','programa','nivel','estado','periodo'], array_map(static fn($r)=>array_values($r), $missingLevels));
$levelRows = []; foreach ($unknownLevels as $level=>$nums) $levelRows[] = [$level,count($nums),implode('|',array_slice($nums,0,100))];
report($outDir, 'niveles_no_reconocidos.csv', ['nivel_excel','filas','filas_ejemplo_max_100'], $levelRows);
report($outDir, 'estados_pendientes.csv', ['fila','programa','nivel','estado','periodo'], array_map(static fn($r)=>array_values($r), $statusIssues));
$periodRows = []; foreach ($periods as $p=>$n) $periodRows[] = [$p,$n,'PENDIENTE'];
arsort($periods); usort($periodRows, static fn($a,$b)=>$b[1]<=>$a[1]);
report($outDir, 'periodos_pendientes.csv', ['periodo_excel','filas','equivalencia_manual'], $periodRows);
echo "ORION v0.11.33 | FASE 2E | SOLO LECTURA\n";
foreach (['filas'=>$total,'identificaciones_vacias'=>$emptyIds,'personas_unicas_con_identificacion'=>count($groups),'personas_existentes_unicas'=>$existingUnique,'personas_nuevas_unicas'=>$newUnique,'filas_personas_existentes'=>$existingRows,'filas_personas_nuevas'=>$newRows,'personas_con_repeticiones'=>$duplicatedPersons,'apariciones_adicionales'=>$additional,'repetidas_con_multiples_programas'=>$multiProgram,'repetidas_con_multiples_periodos'=>$multiPeriod,'filas_programa_pendiente'=>array_sum(array_map('count',$unknownPrograms)),'filas_nivel_vacio'=>count($missingLevels),'filas_nivel_no_reconocido'=>array_sum(array_map('count',$unknownLevels)),'filas_estado_vacio_o_desconocido'=>count($statusIssues),'filas_con_beca'=>$scholarship,'filas_con_ingresos_hogar'=>$income] as $k=>$v) printf("%-42s %d\n",$k,$v);
echo "Reportes locales: $outDir\nNo se modifico MySQL, Moodle ni Microsoft 365.\nATENCION: los CSV incluyen metadatos academicos; no publicarlos.\n";
