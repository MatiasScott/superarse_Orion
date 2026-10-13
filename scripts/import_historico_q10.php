<?php

declare(strict_types=1);

/**
 * Orion v0.8.0 - Importador histórico Q10
 * Uso:
 *   php scripts/import_historico_q10.php --preflight
 *   php scripts/import_historico_q10.php --execute
 * Requiere haber ejecutado seeds 010 y 011.
 */

use App\Core\Config;
use App\Core\Database;
use Dotenv\Dotenv;

define('BASE_PATH', dirname(__DIR__));
require BASE_PATH . '/vendor/autoload.php';
if (is_file(BASE_PATH . '/.env')) Dotenv::createImmutable(BASE_PATH)->safeLoad();
date_default_timezone_set($_ENV['APP_TIMEZONE'] ?? 'America/Guayaquil');
$pdo = (new Database(new Config($_ENV)))->connection();
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
$mode = in_array('--execute', $argv, true) ? 'execute' : 'preflight';
$dataDir = BASE_PATH . '/storage/import/historico_q10';

function csvRows(string $file): Generator
{
    $h = fopen($file, 'rb');
    if (!$h) throw new RuntimeException("No se puede abrir $file");
    $head = fgetcsv($h);
    if (!$head) throw new RuntimeException("CSV vacío: $file");
    $head = array_map(fn($v) => preg_replace('/^\xEF\xBB\xBF/', '', (string)$v), $head);
    while (($r = fgetcsv($h)) !== false) {
        if (count($r) < count($head)) $r = array_pad($r, count($head), '');
        yield array_combine($head, array_slice($r, 0, count($head)));
    }
    fclose($h);
}
function one(PDO $db, string $sql, array $p = []): mixed
{
    $s = $db->prepare($sql);
    $s->execute($p);
    $r = $s->fetchColumn();
    return $r === false ? null : $r;
}
function row(PDO $db, string $sql, array $p = []): ?array
{
    $s = $db->prepare($sql);
    $s->execute($p);
    $r = $s->fetch();
    return $r ?: null;
}
function execq(PDO $db, string $sql, array $p = []): void
{
    $s = $db->prepare($sql);
    $s->execute($p);
}
function n(?string $v): ?float
{
    $v = trim((string)$v);
    return $v === '' ? null : (float)$v;
}
function clean(?string $v): ?string
{
    $v = trim((string)$v);
    return $v === '' ? null : $v;
}
function excelDate(?string $v): ?string
{
    $v = trim((string)$v);
    if ($v === '') return null;
    if (is_numeric($v)) {
        $base = new DateTimeImmutable('1899-12-30');
        return $base->modify('+' . ((int)floor((float)$v)) . ' days')->format('Y-m-d');
    }
    $t = strtotime($v);
    return $t ? date('Y-m-d', $t) : null;
}
function q10Date(?string $v): ?string
{
    $v = trim((string)$v);
    if ($v === '') return null;
    foreach (['d/m/Y', 'Y-m-d'] as $f) {
        $d = DateTimeImmutable::createFromFormat($f, $v);
        if ($d) return $d->format('Y-m-d');
    }
    return excelDate($v);
}
function code(string $s, int $max = 50): string
{
    $x = iconv('UTF-8', 'ASCII//TRANSLIT//IGNORE', $s) ?: $s;
    $x = strtoupper($x);
    $x = preg_replace('/[^A-Z0-9]+/', '_', $x);
    $x = trim($x, '_');
    return substr($x ?: 'OTRO', 0, $max);
}
function incident(PDO $db, string $type, string $sev, string $ref, string $detail): void
{
    execq($db, "INSERT INTO migracion_q10_historico_incidentes(tipo,severidad,referencia,detalle) VALUES(?,?,?,?) ON DUPLICATE KEY UPDATE severidad=VALUES(severidad),detalle=VALUES(detalle)", [$type, $sev, substr($ref, 0, 255), $detail]);
}
function catalogId(PDO $db, string $table, string $code): ?int
{
    $allowed = ['tipos_identificacion', 'sexos', 'estados_civiles', 'tipos_sangre', 'etnias', 'tipos_telefono', 'tipos_correo', 'tipos_direccion', 'estados_estudiante', 'estados_trayectoria_academica', 'tipos_ingreso_estudiante', 'modalidades_academicas', 'niveles_academicos', 'estados_periodo_academico', 'tipos_periodo_academico', 'estados_oferta_academica', 'estados_seccion', 'tipos_matricula', 'estados_matricula', 'estados_matricula_asignatura', 'estados_esquema_evaluacion', 'tipos_recurso_evaluable', 'origenes_recurso_evaluable', 'estados_recurso_evaluable', 'estados_calificacion_recurso', 'origenes_calificacion', 'resultados_academicos_catalogo', 'estados_supletorio'];
    if (!in_array($table, $allowed, true)) throw new RuntimeException('Catálogo no permitido');
    $v = one($db, "SELECT id FROM $table WHERE codigo=? LIMIT 1", [$code]);
    return $v === null ? null : (int)$v;
}
function programMap(PDO $db, string $program): ?array
{
    return row($db, "SELECT id,carrera_id,sede_id,q10_programa_codigo FROM migracion_q10_programas WHERE TRIM(q10_programa_nombre)=TRIM(?) LIMIT 1", [$program]);
}
function periodId(PDO $db, string $name): ?int
{
    $v = one($db, "SELECT id FROM periodos_academicos WHERE TRIM(nombre)=TRIM(?) AND deleted_at IS NULL LIMIT 1", [$name]);
    return $v === null ? null : (int)$v;
}
function personById(PDO $db, string $ident): ?array
{
    return row($db, "SELECT p.*,e.id estudiante_id FROM personas p LEFT JOIN estudiantes e ON e.persona_id=p.id AND e.deleted_at IS NULL WHERE p.numero_identificacion=? AND p.deleted_at IS NULL LIMIT 1", [$ident]);
}

$required = ['migracion_q10_programas', 'migracion_q10_mallas', 'migracion_q10_asignaturas', 'migracion_q10_historico_cursos', 'migracion_q10_historico_notas'];
foreach ($required as $t) {
    if (!(int)one($pdo, "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name=?", [$t])) throw new RuntimeException("Falta $t. Ejecute seeds 010 y 011.");
}
$files = ['periodos.csv', 'estudiantes_master.csv', 'notas_cursos.csv', 'notas_estudiantes.csv', 'notas_parametros.csv', 'notas_detalle.csv'];
foreach ($files as $f) if (!is_file("$dataDir/$f")) throw new RuntimeException("Falta $dataDir/$f");

if ($mode === 'preflight') {
    $counts = [];
    foreach ($files as $f) {
        $c = 0;
        foreach (csvRows("$dataDir/$f") as $_) $c++;
        $counts[$f] = $c;
    }
    echo "ORION v0.8.0 - PREFLIGHT HISTÓRICO Q10\n";
    foreach ($counts as $f => $c) echo str_pad($f, 28) . " $c\n";
    echo "Programas Q10 mapeados DB: " . one($pdo, "SELECT COUNT(*) FROM migracion_q10_programas") . "\n";
    echo "Asignaturas Q10 mapeadas DB: " . one($pdo, "SELECT COUNT(*) FROM migracion_q10_asignaturas") . "\n";
    echo "Esquemas históricos: " . one($pdo, "SELECT COUNT(*) FROM esquemas_evaluacion WHERE codigo LIKE 'Q10_HIST_%'") . "\n";
    echo "Resultado esperado: 18 periodos fuente, 3330 filas maestro, 749 cursos, 14632 notas, 87752 notas-parametro.\n";
    exit(0);
}

$run = 'HIST_Q10_V080';
execq($pdo, "INSERT INTO migracion_q10_historico_ejecuciones(codigo,estado,iniciada_at,error_text) VALUES(?, 'INICIADA', NOW(), NULL) ON DUPLICATE KEY UPDATE estado='INICIADA',iniciada_at=NOW(),finalizada_at=NULL,error_text=NULL", [$run]);
$stats = ['periodos' => 0, 'personas_nuevas' => 0, 'estudiantes_nuevos' => 0, 'trayectorias' => 0, 'cursos' => 0, 'notas' => 0, 'detalle_parametros' => 0, 'incidentes' => 0];
try {
    $pdo->beginTransaction();
    $inst = (int)one($pdo, "SELECT id FROM instituciones WHERE codigo='SUPERARSE' LIMIT 1");
    if (!$inst) throw new RuntimeException('No existe institución SUPERARSE');

    // 1) Periodos: conservar ordenamiento explícito, no derivarlo del ID.
    foreach (csvRows("$dataDir/periodos.csv") as $r) {
        $name = trim($r['nombre']);
        $order = (int)$r['ordenamiento'];
        $start = $r['fecha_inicio'];
        $end = $r['fecha_fin'];
        $type = str_starts_with(strtoupper($name), 'PAE') ? 'EXTRAORDINARIO' : 'ORDINARIO';
        $today = date('Y-m-d');
        $state = $end < $today ? 'CERRADO' : ($start <= $today && $end >= $today ? 'EN_CURSO' : 'PLANIFICACION');
        $id = periodId($pdo, $name);
        if (!$id) {
            execq($pdo, "INSERT INTO periodos_academicos(institucion_id,tipo_periodo_id,estado_periodo_id,codigo,nombre,fecha_inicio,fecha_fin,ordenamiento,activo) VALUES(?,?,?,?,?,?,?,?,1)", [$inst, catalogId($pdo, 'tipos_periodo_academico', $type), catalogId($pdo, 'estados_periodo_academico', $state), 'Q10-P' . str_pad((string)$order, 2, '0', STR_PAD_LEFT), $name, $start, $end, $order]);
        } else execq($pdo, "UPDATE periodos_academicos SET fecha_inicio=?,fecha_fin=?,ordenamiento=?,tipo_periodo_id=?,updated_at=NOW() WHERE id=?", [$start, $end, $order, catalogId($pdo, 'tipos_periodo_academico', $type), $id]);
        $stats['periodos']++;
    }

    // Cargar filas maestro y agrupar por identidad. Se excluyen pruebas/autoevaluación/seguimiento.
    $master = [];
    $byIdentity = [];
    foreach (csvRows("$dataDir/estudiantes_master.csv") as $r) {
        $master[] = $r;
        if ((int)$r['excluded'] === 0 && trim($r['Número de identificación']) !== '') $byIdentity[trim($r['Número de identificación'])][] = $r;
    }
    $periodOrder = [];
    foreach (csvRows("$dataDir/periodos.csv") as $r) $periodOrder[trim($r['nombre'])] = (int)$r['ordenamiento'];

    foreach ($byIdentity as $ident => $rows) {
        usort($rows, fn($a, $b) => ($periodOrder[trim($a['Período'])] ?? 0) <=> ($periodOrder[trim($b['Período'])] ?? 0));
        $latest = end($rows);
        reset($rows);
        $p = personById($pdo, (string) $ident);
        if (!$p) {
            $tid = str_contains(code($latest['Tipo de identificación']), 'CEDULA') ? 'CEDULA' : (str_contains(code($latest['Tipo de identificación']), 'PASAP') ? 'PASAPORTE' : 'OTRO');
            $sex = strtoupper(trim($latest['Sexo'])) === 'FEMENINO' ? 'FEMENINO' : (strtoupper(trim($latest['Sexo'])) === 'MASCULINO' ? 'MASCULINO' : 'NO_ESPECIFICA');
            execq($pdo, "INSERT INTO personas(tipo_identificacion_id,numero_identificacion,primer_nombre,segundo_nombre,primer_apellido,segundo_apellido,fecha_nacimiento,sexo_id,activo) VALUES(?,?,?,?,?,?,?,?,1)", [catalogId($pdo, 'tipos_identificacion', $tid), $ident, trim($latest['Primer nombre']), clean($latest['Segundo nombre']), trim($latest['Primer apellido']), clean($latest['Segundo apellido']), excelDate($latest['Fecha de nacimiento']), catalogId($pdo, 'sexos', $sex)]);
            $stats['personas_nuevas']++;
            $p = personById($pdo, (string) $ident);
        } else {
            execq($pdo, "UPDATE personas SET fecha_nacimiento=COALESCE(fecha_nacimiento,?),updated_at=NOW() WHERE id=?", [excelDate($latest['Fecha de nacimiento']), $p['id']]);
        }
        $personId = (int)$p['id'];
        $studentId = $p['estudiante_id'] ? (int)$p['estudiante_id'] : 0;
        // Completar catálogos personales solo cuando Orion aún no tiene el dato.
        $ec = code($latest['Estado Civil'] ?? '');
        $ecCode = str_contains($ec, 'SOLTER') ? 'SOLTERO' : (str_contains($ec, 'CASAD') ? 'CASADO' : (str_contains($ec, 'DIVOR') ? 'DIVORCIADO' : (str_contains($ec, 'VIUD') ? 'VIUDO' : (str_contains($ec, 'UNION') ? 'UNION_HECHO' : null))));
        $et = code($latest['Etnia'] ?? '');
        $etCode = str_contains($et, 'INDIG') ? 'INDIGENA' : (str_contains($et, 'AFRO') ? 'AFROECUATORIANO' : (str_contains($et, 'MONTUB') ? 'MONTUBIO' : (str_contains($et, 'MESTIZ') ? 'MESTIZO' : (str_contains($et, 'BLANC') ? 'BLANCO' : null))));
        $blood = preg_replace('/^\d+\s*/', '', trim($latest['Tipo de Sangre'] ?? ''));
        $blood = strtoupper(str_replace(' ', '', $blood));
        $bloodId = $blood !== '' ? one($pdo, "SELECT id FROM tipos_sangre WHERE codigo=?", [$blood]) : null;
        execq($pdo, "UPDATE personas SET estado_civil_id=COALESCE(estado_civil_id,?),etnia_id=COALESCE(etnia_id,?),tipo_sangre_id=COALESCE(tipo_sangre_id,?),pueblo_nacionalidad=COALESCE(pueblo_nacionalidad,?),updated_at=NOW() WHERE id=?", [$ecCode ? one($pdo, "SELECT id FROM estados_civiles WHERE codigo=?", [$ecCode]) : null, $etCode ? one($pdo, "SELECT id FROM etnias WHERE codigo=?", [$etCode]) : null, $bloodId, clean($latest['Pueblo y Nacionalidad ( indígena)'] ?? ''), $personId]);
        if (!$studentId) {
            $state = 'ACTIVO';
            $s = strtoupper(trim($latest['Estado']));
            if (str_contains($s, 'GRADU')) $state = 'GRADUADO';
            elseif (str_contains($s, 'EGRES')) $state = 'EGRESADO';
            elseif (str_contains($s, 'CANCEL') || str_contains($s, 'INACT')) $state = 'BAJA';
            $firstDates = array_filter(array_map(fn($x) => excelDate($x['Fecha de matrícula']), $rows));
            sort($firstDates);
            $fi = $firstDates[0] ?? null;
            execq($pdo, "INSERT INTO estudiantes(persona_id,estado_estudiante_id,codigo_estudiante,fecha_ingreso,activo) VALUES(?,?,?,?,1)", [$personId, catalogId($pdo, 'estados_estudiante', $state), 'Q10-EST-' . $ident, $fi]);
            $studentId = (int)$pdo->lastInsertId();
            $stats['estudiantes_nuevos']++;
        }
        // Correos/teléfonos/dirección: se agregan sin borrar datos existentes. Placeholder 0987654321 se conserva en CSV y se marca, pero no se publica como teléfono oficial.
        foreach ($rows as $rr) {
            foreach ([['Correo electrónico', 'INSTITUCIONAL', 1], ['Correo Personal', 'PERSONAL', 0]] as [$field, $type, $main]) {
                $mail = strtolower(trim($rr[$field]));
                if ($mail !== '' && filter_var($mail, FILTER_VALIDATE_EMAIL)) execq($pdo, "INSERT INTO persona_correos(persona_id,tipo_correo_id,correo,es_principal,activo) SELECT ?,?,?,?,1 WHERE NOT EXISTS(SELECT 1 FROM persona_correos WHERE persona_id=? AND correo=? AND deleted_at IS NULL)", [$personId, catalogId($pdo, 'tipos_correo', $type), $mail, $main, $personId, $mail]);
            }
            foreach ([['Celular', 'MOVIL', 1], ['Teléfono', 'DOMICILIO', 0]] as [$field, $type, $main]) {
                $phone = preg_replace('/\s+/', '', trim($rr[$field]));
                if ($phone === '0987654321') {
                    incident(
                        $pdo,
                        'DATO_SOSPECHOSO...',
                        'ADVERTENCIA',
                        (string) $ident,
                        'Q10 contiene 09...'
                    );
                    continue;
                }
                if ($phone !== '' && $phone !== '0') execq($pdo, "INSERT INTO persona_telefonos(persona_id,tipo_telefono_id,numero,es_principal,activo) SELECT ?,?,?,?,1 WHERE NOT EXISTS(SELECT 1 FROM persona_telefonos WHERE persona_id=? AND numero=? AND deleted_at IS NULL)", [$personId, catalogId($pdo, 'tipos_telefono', $type), $phone, $main, $personId, $phone]);
            }
            $addr = trim($rr['Dirección']);
            if ($addr !== '') execq($pdo, "INSERT INTO persona_direcciones(persona_id,tipo_direccion_id,barrio,direccion_linea1,es_principal,activo) SELECT ?,?,?,?,1,1 WHERE NOT EXISTS(SELECT 1 FROM persona_direcciones WHERE persona_id=? AND direccion_linea1=? AND deleted_at IS NULL)", [$personId, catalogId($pdo, 'tipos_direccion', 'DOMICILIO'), clean($rr['Barrio']), $addr, $personId, $addr]);
        }
        // Ficha Situacional: para no pisar una ficha ya trabajada en Orion, solo se crea cuando no existe una vigente.
        $hasSoc = (int)one($pdo, "SELECT COUNT(*) FROM estudiante_datos_socioeconomicos WHERE estudiante_id=? AND vigente_hasta IS NULL", [$studentId]);
        $socioFields = ['Ocupación del Estudiante', 'Recibe el Bono de Desarrollo Humano (núcleo familiar)', 'Nivel de Formación del Padre', 'Nivel de Formación del Madre', 'Ingresos del Hogar', 'Numero de Miembros del Hogar 1', 'Tipo de Colegio ', 'TIENE AYUDA ECONOMICA', 'Valor de Ayuda Económica '];
        $hasSource = false;
        foreach ($socioFields as $sf) if (trim($latest[$sf] ?? '') !== '') {
            $hasSource = true;
            break;
        }
        if ($hasSource && !$hasSoc) {
            $occCode = null;
            $oc = code($latest['Ocupación del Estudiante'] ?? '');
            if (str_contains($oc, 'SOLO_ESTUDIA')) $occCode = 'SOLO_ESTUDIA';
            elseif (str_contains($oc, 'ESTUDIA') && str_contains($oc, 'TRABA')) $occCode = 'ESTUDIA_TRABAJA';
            elseif (str_contains($oc, 'TRABA')) $occCode = 'TRABAJA';
            elseif ($oc !== '') $occCode = 'OTRO';
            $form = function (string $v): string {
                $c = code($v);
                if (str_contains($c, 'ALFABET')) return 'ALFABETIZACION';
                if (str_contains($c, 'PRIMAR')) return 'PRIMARIA';
                if (str_contains($c, 'SECUND') || str_contains($c, 'BACHILL')) return 'SECUNDARIA';
                if (str_contains($c, 'TECN') || str_contains($c, 'TECNO')) return 'TECNICO_TECNOLOGICO';
                if (str_contains($c, 'TERCER')) return 'TERCER_NIVEL';
                if (str_contains($c, 'CUARTO')) return 'CUARTO_NIVEL';
                if (str_contains($c, 'SIN_INSTRU')) return 'SIN_INSTRUCCION';
                return 'NO_ESPECIFICA';
            };
            $college = null;
            $cc = code($latest['Tipo de Colegio '] ?? '');
            if (str_contains($cc, 'PUBLIC')) $college = 'PUBLICO';
            elseif (str_contains($cc, 'PRIV')) $college = 'PRIVADO';
            elseif (str_contains($cc, 'FISCOM')) $college = 'FISCOMISIONAL';
            elseif (str_contains($cc, 'MUNIC')) $college = 'MUNICIPAL';
            elseif ($cc !== '') $college = 'OTRO';
            $yesno = function (string $v): ?int {
                $c = code($v);
                if ($c === '') return null;
                if (str_starts_with($c, 'SI')) return 1;
                if (str_starts_with($c, 'NO')) return 0;
                return null;
            };
            $money = function (string $v): ?float {
                $v = preg_replace('/[^0-9,.-]/', '', $v);
                if ($v === '') return null;
                if (str_contains($v, ',') && !str_contains($v, '.')) $v = str_replace(',', '.', $v);
                elseif (str_contains($v, ',') && str_contains($v, '.')) $v = str_replace(',', '', $v);
                return is_numeric($v) ? (float)$v : null;
            };
            $vd = excelDate($latest['Última fecha de actualización'] ?? '');
            if (!$vd && trim($latest['Período'] ?? '') !== '') {
                $pp = periodId($pdo, trim($latest['Período']));
                if ($pp) $vd = (string)one($pdo, "SELECT fecha_inicio FROM periodos_academicos WHERE id=?", [$pp]);
            }
            if ($vd) execq($pdo, "INSERT INTO estudiante_datos_socioeconomicos(estudiante_id,ocupacion_id,recibe_bono_desarrollo_humano,nivel_formacion_padre_id,nivel_formacion_madre_id,ingresos_hogar,numero_miembros_hogar,tipo_colegio_id,tiene_ayuda_economica,valor_ayuda_economica,vigente_desde,vigente_hasta) VALUES(?,?,?,?,?,?,?,?,?,?,?,NULL)", [$studentId, $occCode ? one($pdo, "SELECT id FROM ocupaciones_estudiante WHERE codigo=?", [$occCode]) : null, $yesno($latest['Recibe el Bono de Desarrollo Humano (núcleo familiar)'] ?? ''), one($pdo, "SELECT id FROM niveles_formacion_familiar WHERE codigo=?", [$form($latest['Nivel de Formación del Padre'] ?? '')]), one($pdo, "SELECT id FROM niveles_formacion_familiar WHERE codigo=?", [$form($latest['Nivel de Formación del Madre'] ?? '')]), $money($latest['Ingresos del Hogar'] ?? ''), ($money($latest['Numero de Miembros del Hogar 1'] ?? '') ?: null), $college ? one($pdo, "SELECT id FROM tipos_colegio WHERE codigo=?", [$college]) : null, $yesno($latest['TIENE AYUDA ECONOMICA'] ?? ''), $money($latest['Valor de Ayuda Económica '] ?? ''), $vd]);
        } elseif ($hasSource && $hasSoc) {
            incident($pdo, 'FICHA_SITUACIONAL_EXISTENTE', 'INFO', (string) $ident, 'Ya existe ficha vigente en Orion; la migración no la sobrescribe. La fuente Q10 queda preservada en estudiantes_master.csv.');
        }

        // Trayectorias por programa real. Una identidad puede tener varias carreras.
        $progRows = [];
        foreach ($rows as $rr) $progRows[trim($rr['Programa'])][] = $rr;
        foreach ($progRows as $program => $prs) {
            $pm = programMap($pdo, $program);
            if (!$pm) {
                incident($pdo, 'PROGRAMA_SIN_MAPEO', 'ADVERTENCIA', $ident . '|' . $program, 'Programa del maestro no existe en migracion_q10_programas.');
                continue;
            }
            usort($prs, fn($a, $b) => ($periodOrder[trim($a['Período'])] ?? 0) <=> ($periodOrder[trim($b['Período'])] ?? 0));
            $first = $prs[0];
            $last = end($prs);
            $mm = row($pdo, "SELECT mm.malla_id FROM migracion_q10_mallas mm WHERE mm.migracion_q10_programa_id=? ORDER BY mm.q10_malla_orden ASC LIMIT 1", [$pm['id']]);
            if (!$mm) continue;
            $start = excelDate($first['Fecha de matrícula']);
            if (!$start && trim($first['Período']) !== '') {
                $pid0 = periodId($pdo, trim($first['Período']));
                if ($pid0) $start = (string)one($pdo, "SELECT fecha_inicio FROM periodos_academicos WHERE id=?", [$pid0]);
            }
            if (!$start) {
                incident($pdo, 'TRAYECTORIA_SIN_FECHA', 'ADVERTENCIA', $ident . '|' . $program, 'No hay fecha de matrícula ni período fuente; la trayectoria no se inventa.');
                continue;
            }
            $st = 'ACTIVA';
            $es = strtoupper(trim($last['Estado']));
            if (str_contains($es, 'GRADU')) $st = 'GRADUADA';
            elseif (str_contains($es, 'EGRES')) $st = 'EGRESADA';
            elseif (str_contains($es, 'CANCEL') || str_contains($es, 'INACT')) $st = 'RETIRADA';
            $existing = one($pdo, "SELECT id FROM estudiante_carreras WHERE estudiante_id=? AND carrera_id=? AND deleted_at IS NULL ORDER BY fecha_inicio LIMIT 1", [$studentId, $pm['carrera_id']]);
            if (!$existing) {
                execq($pdo, "INSERT INTO estudiante_carreras(estudiante_id,carrera_id,malla_id,estado_trayectoria_id,sede_id,fecha_inicio,activo) VALUES(?,?,?,?,?,?,1)", [$studentId, $pm['carrera_id'], $mm['malla_id'], catalogId($pdo, 'estados_trayectoria_academica', $st), $pm['sede_id'], $start]);
                $stats['trayectorias']++;
            }
        }
    }

    // 3) Cursos/secciones. Cada asignatura de los 749 archivos tiene mapping Q10 único validado.
    $courseMap = [];
    $courseScheme = [];
    foreach (csvRows("$dataDir/notas_cursos.csv") as $r) {
        $pid = periodId($pdo, trim($r['periodo']));
        $map = row($pdo, "SELECT mp.carrera_id,mp.sede_id,mm.malla_id,ma.malla_asignatura_id FROM migracion_q10_programas mp JOIN migracion_q10_mallas mm ON mm.migracion_q10_programa_id=mp.id AND mm.q10_malla_orden=? JOIN migracion_q10_asignaturas ma ON ma.migracion_q10_malla_id=mm.id AND ma.q10_asignatura_codigo=? WHERE mp.q10_programa_codigo=? LIMIT 1", [(int)$r['q10_malla_orden'], $r['q10_asignatura_codigo'], $r['q10_programa_codigo']]);
        if (!$pid || !$map) {
            incident($pdo, 'CURSO_SIN_MAPEO', 'ERROR', (string)$r['course_id'], $r['file']);
            continue;
        }
        $offerCode = 'Q10-O-' . $pid . '-' . $map['carrera_id'] . '-' . $map['malla_id'];
        $offer = one($pdo, "SELECT id FROM ofertas_academicas WHERE periodo_academico_id=? AND codigo=?", [$pid, $offerCode]);
        if (!$offer) {
            execq($pdo, "INSERT INTO ofertas_academicas(periodo_academico_id,carrera_id,malla_id,sede_id,estado_oferta_id,codigo,nombre,activo) VALUES(?,?,?,?,?,?,?,1)", [$pid, $map['carrera_id'], $map['malla_id'], $map['sede_id'], catalogId($pdo, 'estados_oferta_academica', 'CERRADA'), $offerCode, 'Oferta histórica Q10 - ' . $r['programa']]);
            $offer = (int)$pdo->lastInsertId();
        }
        $secCode = 'Q10-C' . str_pad((string)$r['course_id'], 4, '0', STR_PAD_LEFT);
        $sec = one($pdo, "SELECT id FROM secciones WHERE oferta_academica_id=? AND codigo=?", [$offer, $secCode]);
        if (!$sec) {
            execq($pdo, "INSERT INTO secciones(oferta_academica_id,malla_asignatura_id,estado_seccion_id,codigo,nombre,fecha_apertura,fecha_cierre,activo) VALUES(?,?,?,?,?,?,?,1)", [$offer, $map['malla_asignatura_id'], catalogId($pdo, 'estados_seccion', 'CERRADA'), $secCode, $r['curso'] ?: $r['asignatura'], q10Date($r['fecha_inicio']), q10Date($r['fecha_fin'])]);
            $sec = (int)$pdo->lastInsertId();
        }
        $schemeCode = $r['scheme'] === 'GENERAL_2P_9PARAM' ? 'Q10_HIST_GENERAL' : ($r['scheme'] === 'PRACTICAS_2P_1PARAM' ? 'Q10_HIST_PRACTICAS' : 'Q10_HIST_FINAL');
        $ver = (int)one($pdo, "SELECT v.id FROM esquema_evaluacion_versiones v JOIN esquemas_evaluacion e ON e.id=v.esquema_evaluacion_id WHERE e.codigo=? AND v.numero_version=1", [$schemeCode]);
        execq($pdo, "INSERT INTO seccion_esquema_evaluacion(seccion_id,esquema_version_id,bloqueado,fecha_bloqueo,observacion) VALUES(?,?,1,NOW(),'Migración histórica Q10') ON DUPLICATE KEY UPDATE esquema_version_id=VALUES(esquema_version_id),bloqueado=1", [$sec, $ver]);
        execq($pdo, "INSERT INTO migracion_q10_historico_cursos(source_course_id,archivo,periodo_q10,programa_q10,asignatura_q10,curso_q10,docente_q10,esquema_fuente,periodo_academico_id,carrera_id,malla_id,malla_asignatura_id,oferta_academica_id,seccion_id,estado,imported_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,'IMPORTADO',NOW()) ON DUPLICATE KEY UPDATE periodo_academico_id=VALUES(periodo_academico_id),carrera_id=VALUES(carrera_id),malla_id=VALUES(malla_id),malla_asignatura_id=VALUES(malla_asignatura_id),oferta_academica_id=VALUES(oferta_academica_id),seccion_id=VALUES(seccion_id),estado='IMPORTADO',imported_at=NOW()", [(int)$r['course_id'], $r['file'], $r['periodo'], $r['programa'], $r['asignatura'], clean($r['curso']), clean($r['docente']), $r['scheme'], $pid, $map['carrera_id'], $map['malla_id'], $map['malla_asignatura_id'], $offer, $sec]);
        $courseMap[(int)$r['course_id']] = ['period' => $pid, 'program' => $r['programa'], 'career' => (int)$map['carrera_id'], 'malla' => (int)$map['malla_id'], 'ma' => (int)$map['malla_asignatura_id'], 'offer' => (int)$offer, 'section' => $sec, 'scheme' => $r['scheme'], 'version' => $ver];
        $courseScheme[(int)$r['course_id']] = $r['scheme'];
        $stats['cursos']++;
        if (trim($r['docente']) !== '') incident($pdo, 'DOCENTE_Q10_PENDIENTE_VINCULO', 'INFO', (string)$r['course_id'], 'Docente preservado como fuente: ' . $r['docente'] . '. No se crea persona sin identificación.');
    }

    // Parámetros por curso -> recurso histórico por parámetro. Preserva nombre crudo en CSV y usa orden canónico del esquema.
    $paramByCourse = [];
    $paramSeq = [];
    foreach (csvRows("$dataDir/notas_parametros.csv") as $r) {
        $cid = (int)$r['course_id'];
        $par = (int)$r['partial'];
        $key = $cid . '|' . $par;
        $paramSeq[$key] = ($paramSeq[$key] ?? 0) + 1;
        $paramByCourse[$cid][$r['column']] = ['partial' => $par, 'order' => $paramSeq[$key], 'raw' => $r['nombre']];
    }
    $resourceMap = [];
    foreach ($paramByCourse as $cid => $plist) {
        if (!isset($courseMap[$cid])) continue;
        $c = $courseMap[$cid];
        foreach ($plist as $col => $pp) {
            $param = row($pdo, "SELECT pe.id,pe.nombre FROM parametros_evaluacion pe JOIN parciales_evaluacion pa ON pa.id=pe.parcial_id WHERE pa.esquema_version_id=? AND pa.orden_visual=? AND pe.orden_visual=? LIMIT 1", [$c['version'], $pp['partial'], $pp['order']]);
            if (!$param) continue;
            $ext = 'Q10-HIST-C' . $cid . '-' . $col;
            $res = one($pdo, "SELECT id FROM recursos_evaluables WHERE seccion_id=? AND external_resource_id=?", [$c['section'], $ext]);
            if (!$res) {
                execq($pdo, "INSERT INTO recursos_evaluables(seccion_id,tipo_recurso_id,origen_recurso_id,estado_recurso_id,nombre,descripcion,calificacion_maxima,external_resource_id,visible,activo) VALUES(?,?,?,?,?,?,10,?,1,1)", [$c['section'], catalogId($pdo, 'tipos_recurso_evaluable', 'OTRO_EVALUABLE'), catalogId($pdo, 'origenes_recurso_evaluable', 'IMPORTACION'), catalogId($pdo, 'estados_recurso_evaluable', 'ACTIVO'), $param['nombre'], 'Fuente Q10: ' . $pp['raw'], $ext]);
                $res = (int)$pdo->lastInsertId();
            }
            execq($pdo, "INSERT INTO recurso_parametro_evaluacion(seccion_id,recurso_id,parametro_evaluacion_id,activo) VALUES(?,?,?,1) ON DUPLICATE KEY UPDATE parametro_evaluacion_id=VALUES(parametro_evaluacion_id),activo=1", [$c['section'], $res, $param['id']]);
            $resourceMap[$cid][$col] = (int)$res;
        }
    }
    // Recurso final para reportes antiguos.
    foreach ($courseMap as $cid => $c) {
        if ($c['scheme'] !== 'FINAL_HISTORICO') continue;
        $param = (int)one($pdo, "SELECT pe.id FROM parametros_evaluacion pe JOIN parciales_evaluacion pa ON pa.id=pe.parcial_id WHERE pa.esquema_version_id=? LIMIT 1", [$c['version']]);
        $ext = 'Q10-HIST-C' . $cid . '-FINAL';
        $res = one($pdo, "SELECT id FROM recursos_evaluables WHERE seccion_id=? AND external_resource_id=?", [$c['section'], $ext]);
        if (!$res) {
            execq($pdo, "INSERT INTO recursos_evaluables(seccion_id,tipo_recurso_id,origen_recurso_id,estado_recurso_id,nombre,descripcion,calificacion_maxima,external_resource_id,visible,activo) VALUES(?,?,?,?,?,?,10,?,1,1)", [$c['section'], catalogId($pdo, 'tipos_recurso_evaluable', 'OTRO_EVALUABLE'), catalogId($pdo, 'origenes_recurso_evaluable', 'IMPORTACION'), catalogId($pdo, 'estados_recurso_evaluable', 'ACTIVO'), 'Nota final histórica', 'Fuente Q10 - histórico final', $ext]);
            $res = (int)$pdo->lastInsertId();
        }
        execq($pdo, "INSERT INTO recurso_parametro_evaluacion(seccion_id,recurso_id,parametro_evaluacion_id,activo) VALUES(?,?,?,1) ON DUPLICATE KEY UPDATE parametro_evaluacion_id=VALUES(parametro_evaluacion_id),activo=1", [$c['section'], $res, $param]);
        $resourceMap[$cid]['FINAL'] = (int)$res;
    }

    // Detalle de parámetros en memoria por grade_id.
    $detail = [];
    foreach (csvRows("$dataDir/notas_detalle.csv") as $r) $detail[(int)$r['grade_id']][] = $r;
    $policy = (int)one($pdo, "SELECT v.id FROM politica_resultado_versiones v JOIN politicas_resultado_academico p ON p.id=v.politica_resultado_id WHERE p.codigo='Q10_HISTORICO' AND v.numero_version=1");

    // 4) Matrículas, intentos y calificaciones.
    foreach (csvRows("$dataDir/notas_estudiantes.csv") as $g) {
        $gid = (int)$g['grade_id'];
        $cid = (int)$g['course_id'];
        if (!isset($courseMap[$cid])) continue;
        $c = $courseMap[$cid];
        $ident = trim($g['identificacion']);
        if ($ident === '') {
            incident($pdo, 'NOTA_SIN_IDENTIDAD', 'ERROR', (string)$gid, $g['estudiante_nombre']);
            continue;
        }
        $p = personById($pdo, (string) $ident);
        if (!$p || !$p['estudiante_id']) {
            incident($pdo, 'NOTA_SIN_ESTUDIANTE', 'ERROR', (string) $gid, (string) $ident);
            continue;
        }
        $student = (int)$p['estudiante_id'];
        $traj = row($pdo, "SELECT id FROM estudiante_carreras WHERE estudiante_id=? AND carrera_id=? AND malla_id=? AND deleted_at IS NULL ORDER BY fecha_inicio LIMIT 1", [$student, $c['career'], $c['malla']]);
        if (!$traj) {
            $pm = programMap($pdo, $c['program']);
            $start = (string)one($pdo, "SELECT fecha_inicio FROM periodos_academicos WHERE id=?", [$c['period']]);
            execq($pdo, "INSERT INTO estudiante_carreras(estudiante_id,carrera_id,malla_id,estado_trayectoria_id,sede_id,fecha_inicio,activo) VALUES(?,?,?,?,?,?,1)", [$student, $c['career'], $c['malla'], catalogId($pdo, 'estados_trayectoria_academica', 'ACTIVA'), $pm['sede_id'] ?? null, $start]);
            $traj = ['id' => (int)$pdo->lastInsertId()];
            $stats['trayectorias']++;
        }
        $trajId = (int)$traj['id'];
        $num = 'Q10H-' . (string) $ident . '-' . (string) $c['period'] . '-' . (string) $c['career'] . '-' . (string) $c['malla'];

        /*
|--------------------------------------------------------------------------
| Matrícula histórica
|--------------------------------------------------------------------------
| Primero buscamos por el número histórico estable generado desde Q10.
| Esto permite reanudar la migración sin duplicar matrículas creadas
| durante una ejecución anterior interrumpida.
*/
        $mat = one(
            $pdo,
            "SELECT id
     FROM matriculas
     WHERE numero_matricula=?
       AND estudiante_carrera_id=?
       AND periodo_academico_id=?
     LIMIT 1",
            [$num, $trajId, $c['period']]
        );

        /*
|--------------------------------------------------------------------------
| Compatibilidad con una matrícula ya existente sin número Q10H
|--------------------------------------------------------------------------
*/
        if (!$mat) {
            $mat = one(
                $pdo,
                "SELECT id
         FROM matriculas
         WHERE estudiante_carrera_id=?
           AND periodo_academico_id=?
         LIMIT 1",
                [$trajId, $c['period']]
            );
        }

        if (!$mat) {
            $order = (int) one(
                $pdo,
                "SELECT ordenamiento
         FROM periodos_academicos
         WHERE id=?",
                [$c['period']]
            );

            $prior = (int) one(
                $pdo,
                "SELECT COUNT(*)
         FROM matriculas m
         JOIN periodos_academicos p
           ON p.id=m.periodo_academico_id
         WHERE m.estudiante_carrera_id=?
           AND p.ordenamiento<?",
                [$trajId, $order]
            );

            $type = $prior === 0 ? 'INICIAL' : 'RENOVACION';

            execq(
                $pdo,
                "INSERT INTO matriculas(
            numero_matricula,
            estudiante_carrera_id,
            periodo_academico_id,
            oferta_academica_id,
            tipo_matricula_id,
            estado_matricula_id,
            fecha_matricula,
            fecha_confirmacion,
            generada_automaticamente,
            observacion,
            activo
        )
        VALUES(
            ?,?,?,?,?,?,
            (SELECT fecha_inicio FROM periodos_academicos WHERE id=?),
            (SELECT fecha_inicio FROM periodos_academicos WHERE id=?),
            1,
            'Migración histórica Q10',
            1
        )",
                [
                    $num,
                    $trajId,
                    $c['period'],
                    $c['offer'],
                    catalogId($pdo, 'tipos_matricula', $type),
                    catalogId($pdo, 'estados_matricula', 'FINALIZADA'),
                    $c['period'],
                    $c['period']
                ]
            );

            $mat = (int) $pdo->lastInsertId();
        }
        $final = n($g['nota_final']);
        $state = $final === null ? 'MATRICULADA' : ($final >= 7 ? 'APROBADA' : 'REPROBADA');
        $ma = one($pdo, "SELECT id FROM matricula_asignaturas WHERE matricula_id=? AND seccion_id=?", [$mat, $c['section']]);
        if (!$ma) {
            $asig = (int)one($pdo, "SELECT asignatura_id FROM malla_asignaturas WHERE id=?", [$c['ma']]);
            $order = (int)one($pdo, "SELECT ordenamiento FROM periodos_academicos WHERE id=?", [$c['period']]);
            $attempt = 1 + (int)one($pdo, "SELECT COUNT(*) FROM historial_intentos_asignatura hi JOIN matricula_asignaturas mia ON mia.id=hi.matricula_asignatura_id JOIN matriculas m ON m.id=mia.matricula_id JOIN periodos_academicos p ON p.id=m.periodo_academico_id JOIN malla_asignaturas x ON x.id=hi.malla_asignatura_id WHERE hi.estudiante_carrera_id=? AND x.asignatura_id=? AND p.ordenamiento<?", [$trajId, $asig, $order]);
            if ($attempt > 3) {
                incident($pdo, 'INTENTO_SUPERIOR_TRES', 'ERROR', (string)$gid, "Intento $attempt para $ident; no se inventa un intento fuera de la restricción del esquema.");
                continue;
            }
            execq($pdo, "INSERT INTO matricula_asignaturas(matricula_id,seccion_id,malla_asignatura_id,estado_matricula_asignatura_id,numero_intento,fecha_matricula,observacion,activo) VALUES(?,?,?,?,?,(SELECT fecha_inicio FROM periodos_academicos WHERE id=?),'Migración histórica Q10',1)", [$mat, $c['section'], $c['ma'], catalogId($pdo, 'estados_matricula_asignatura', $state), $attempt, $c['period']]);
            $ma = (int)$pdo->lastInsertId();
            execq($pdo, "INSERT IGNORE INTO historial_intentos_asignatura(estudiante_carrera_id,malla_asignatura_id,matricula_asignatura_id,numero_intento,resultado,nota_final,fecha_resultado) VALUES(?,?,?,?,?,?,(SELECT fecha_fin FROM periodos_academicos WHERE id=?))", [$trajId, $c['ma'], $ma, $attempt, $state, $final, $c['period']]);
        }
        // Final consolidado.
        if ($final !== null) {
            $result = $final >= 7 ? 'APROBADO' : (($final >= 5 && n($g['supletorio']) === null) ? 'HABILITADO_SUPLETORIO' : 'REPROBADO_SIN_SUPLETORIO');
            if (n($g['supletorio']) !== null && $final < 7) $result = 'REPROBADO_SUPLETORIO';
            execq($pdo, "INSERT INTO resultados_finales_asignatura(matricula_asignatura_id,politica_version_id,resultado_academico_id,nota_final_ordinaria,nota_supletorio,nota_final_definitiva,oficial,calculado_at,oficializado_at) VALUES(?,?,?,?,?,?,1,NOW(),NOW()) ON DUPLICATE KEY UPDATE nota_final_ordinaria=VALUES(nota_final_ordinaria),nota_supletorio=VALUES(nota_supletorio),nota_final_definitiva=VALUES(nota_final_definitiva),resultado_academico_id=VALUES(resultado_academico_id),oficial=1", [$ma, $policy, catalogId($pdo, 'resultados_academicos_catalogo', $result), n($g['nota_ordinaria']), n($g['supletorio']), $final]);
        }
        if (n($g['supletorio']) !== null) {
            $sup = n($g['supletorio']);
            $st = $final !== null && $final >= 7 ? 'APROBADO' : 'REPROBADO';
            execq($pdo, "INSERT INTO supletorios(matricula_asignatura_id,estado_supletorio_id,nota_habilitante,nota_supletorio,observacion) VALUES(?,?,?,?,?) ON DUPLICATE KEY UPDATE estado_supletorio_id=VALUES(estado_supletorio_id),nota_habilitante=VALUES(nota_habilitante),nota_supletorio=VALUES(nota_supletorio)", [$ma, catalogId($pdo, 'estados_supletorio', $st), n($g['nota_ordinaria']) ?? 0, $sup, 'Migración histórica Q10']);
        }
        // Parciales consolidados cuando existen.
        if ($c['scheme'] !== 'FINAL_HISTORICO') {
            foreach ([[1, n($g['parcial1'])], [2, n($g['parcial2'])]] as [$po, $pv]) if ($pv !== null) {
                $par = (int)one($pdo, "SELECT id FROM parciales_evaluacion WHERE esquema_version_id=? AND orden_visual=?", [$c['version'], $po]);
                execq($pdo, "INSERT INTO resultados_parciales_estudiante(matricula_asignatura_id,parcial_id,nota_parcial,aporte_nota_final,completo,oficial,calculado_at,oficializado_at) VALUES(?,?,?,?,1,1,NOW(),NOW()) ON DUPLICATE KEY UPDATE nota_parcial=VALUES(nota_parcial),aporte_nota_final=VALUES(aporte_nota_final),completo=1,oficial=1", [$ma, $par, $pv, $pv * 0.5]);
            }
        }
        // Calificaciones por parámetro o nota final antigua.
        if ($c['scheme'] === 'FINAL_HISTORICO' && $final !== null) {
            $res = $resourceMap[$cid]['FINAL'] ?? null;
            if ($res) execq($pdo, "INSERT INTO calificaciones_recursos(recurso_id,matricula_asignatura_id,estado_calificacion_id,origen_calificacion_id,nota_obtenida,nota_maxima,fecha_calificacion,protegida_correccion_oficial) VALUES(?,?,?,?,?,10,NOW(),1) ON DUPLICATE KEY UPDATE nota_obtenida=VALUES(nota_obtenida),estado_calificacion_id=VALUES(estado_calificacion_id),origen_calificacion_id=VALUES(origen_calificacion_id)", [$res, $ma, catalogId($pdo, 'estados_calificacion_recurso', 'OFICIAL'), catalogId($pdo, 'origenes_calificacion', 'MIGRACION'), $final]);
        }
        foreach ($detail[$gid] ?? [] as $d) {
            $res = $resourceMap[$cid][$d['column']] ?? null;
            if (!$res) continue;
            execq($pdo, "INSERT INTO calificaciones_recursos(recurso_id,matricula_asignatura_id,estado_calificacion_id,origen_calificacion_id,nota_obtenida,nota_maxima,fecha_calificacion,protegida_correccion_oficial) VALUES(?,?,?,?,?,10,NOW(),1) ON DUPLICATE KEY UPDATE nota_obtenida=VALUES(nota_obtenida),estado_calificacion_id=VALUES(estado_calificacion_id),origen_calificacion_id=VALUES(origen_calificacion_id)", [$res, $ma, catalogId($pdo, 'estados_calificacion_recurso', 'OFICIAL'), catalogId($pdo, 'origenes_calificacion', 'MIGRACION'), n($d['nota'])]);
            $stats['detalle_parametros']++;
        }
        execq($pdo, "INSERT INTO migracion_q10_historico_notas(source_grade_id,source_course_id,fila_excel,estudiante_q10,identificacion,match_status,matricula_asignatura_id,nota_ordinaria,nota_supletorio,nota_final,inasistencias_acumuladas,observaciones,estado,imported_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?, 'IMPORTADO',NOW()) ON DUPLICATE KEY UPDATE matricula_asignatura_id=VALUES(matricula_asignatura_id),nota_ordinaria=VALUES(nota_ordinaria),nota_supletorio=VALUES(nota_supletorio),nota_final=VALUES(nota_final),inasistencias_acumuladas=VALUES(inasistencias_acumuladas),observaciones=VALUES(observaciones),estado='IMPORTADO',imported_at=NOW()", [$gid, $cid, (int)$g['fila'], $g['estudiante_nombre'], $ident, $g['match_status'], $ma, n($g['nota_ordinaria']), n($g['supletorio']), $final, n($g['inasistencias']), clean($g['observaciones'])]);
        $stats['notas']++;
    }

    $stats['incidentes'] = (int)one($pdo, "SELECT COUNT(*) FROM migracion_q10_historico_incidentes WHERE resuelto=0");
    $pdo->commit();
    execq($pdo, "UPDATE migracion_q10_historico_ejecuciones SET estado='COMPLETADA',finalizada_at=NOW(),resumen_json=? WHERE codigo=?", [json_encode($stats, JSON_UNESCAPED_UNICODE), $run]);
    echo "IMPORTACIÓN COMPLETADA\n";
    foreach ($stats as $k => $v) echo str_pad($k, 24) . " $v\n";
    echo "\nValidación DB:\n";
    echo 'Periodos con ordenamiento: ' . one($pdo, "SELECT COUNT(*) FROM periodos_academicos WHERE ordenamiento IS NOT NULL") . "\n";
    echo 'Cursos Q10 importados: ' . one($pdo, "SELECT COUNT(*) FROM migracion_q10_historico_cursos WHERE estado='IMPORTADO'") . "\n";
    echo 'Notas Q10 importadas: ' . one($pdo, "SELECT COUNT(*) FROM migracion_q10_historico_notas WHERE estado='IMPORTADO'") . "\n";
    echo 'Calificaciones detalle MIGRACION: ' . one($pdo, "SELECT COUNT(*) FROM calificaciones_recursos c JOIN origenes_calificacion o ON o.id=c.origen_calificacion_id WHERE o.codigo='MIGRACION'") . "\n";
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    execq($pdo, "UPDATE migracion_q10_historico_ejecuciones SET estado='ERROR',finalizada_at=NOW(),error_text=? WHERE codigo=?", [$e->getMessage(), $run]);
    fwrite(STDERR, "ERROR: {$e->getMessage()}\n{$e->getTraceAsString()}\n");
    exit(1);
}
