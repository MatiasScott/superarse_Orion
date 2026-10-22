<?php
declare(strict_types=1);
/** Orion v0.11.32 Fase 2C. Solo lectura: no modifica BD ni llama a Moodle/M365. */
use App\Core\Config;
use App\Core\Database;
use Dotenv\Dotenv;

define('BASE_PATH', dirname(__DIR__));
require BASE_PATH . '/vendor/autoload.php';
if (is_file(BASE_PATH . '/.env')) {
    Dotenv::createImmutable(BASE_PATH)->safeLoad();
}

try {
    $db = (new Database(new Config($_ENV)))->connection();
    $db->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
    echo "ORION v0.11.32 - FASE 2C | COBERTURA DE OFERTA (SOLO LECTURA)\n";
    echo str_repeat('=', 75) . "\n";
    $periodos = $db->query("SELECT id, codigo, nombre FROM periodos_academicos WHERE codigo IN ('Q10-P17','Q10-P19') ORDER BY id")->fetchAll();
    $q = $db->prepare(<<<'SQL'
SELECT c.id AS carrera_id, c.nombre AS carrera, mc.id AS malla_id, mc.codigo AS malla,
       em.codigo AS estado_malla, COUNT(DISTINCT ma.id) AS materias_malla,
       COUNT(DISTINCT oa.id) AS ofertas_periodo, COUNT(DISTINCT s.id) AS secciones_periodo,
       COUNT(DISTINCT CASE WHEN eo.permite_matricula=1 AND oa.activo=1
           AND es.permite_matricula=1 AND s.permite_matricula=1 AND s.activo=1 AND s.deleted_at IS NULL
           THEN s.id END) AS secciones_habilitadas
FROM carreras c
JOIN mallas_curriculares mc ON mc.carrera_id=c.id AND mc.deleted_at IS NULL
LEFT JOIN estados_malla em ON em.id=mc.estado_malla_id
LEFT JOIN malla_asignaturas ma ON ma.malla_id=mc.id AND ma.activa=1
LEFT JOIN ofertas_academicas oa ON oa.malla_id=mc.id AND oa.periodo_academico_id=:periodo
LEFT JOIN estados_oferta_academica eo ON eo.id=oa.estado_oferta_id
LEFT JOIN secciones s ON s.oferta_academica_id=oa.id
LEFT JOIN estados_seccion es ON es.id=s.estado_seccion_id
WHERE c.deleted_at IS NULL
GROUP BY c.id,c.nombre,mc.id,mc.codigo,em.codigo
ORDER BY c.nombre,mc.codigo
SQL);
    foreach ($periodos as $p) {
        printf("\nPERIODO %s | %s\n", $p['codigo'], $p['nombre']);
        $q->execute(['periodo' => (int)$p['id']]);
        $faltantes=0;
        foreach ($q as $r) {
            printf("  %-53.53s %-9s estado=%-11s materias=%2d ofertas=%d secciones=%d habilitadas=%d%s\n",
                $r['carrera'], $r['malla'], $r['estado_malla'] ?? '-',
                (int)$r['materias_malla'], (int)$r['ofertas_periodo'],
                (int)$r['secciones_periodo'], (int)$r['secciones_habilitadas'],
                (int)$r['ofertas_periodo']===0 ? ' [SIN OFERTA]' : '');
            if ((int)$r['ofertas_periodo']===0) $faltantes++;
        }
        printf("  Mallas sin oferta en este periodo: %d (NO implica que deban ofertarse todas)\n", $faltantes);
    }
    echo "\nSECCIONES Q10-P19 (sin datos personales)\n";
    foreach ($db->query(<<<'SQL'
SELECT oa.id AS oferta_id, oa.codigo AS oferta, eo.codigo AS estado_oferta,
       s.id AS seccion_id, s.codigo AS seccion, es.codigo AS estado_seccion,
       eo.permite_matricula AS oferta_permite, es.permite_matricula AS estado_permite,
       s.permite_matricula AS bandera_permite, s.activo AS activa, s.deleted_at,
       (SELECT COUNT(*) FROM matricula_asignaturas mas WHERE mas.seccion_id=s.id AND mas.activo=1) AS matriculados
FROM ofertas_academicas oa
JOIN periodos_academicos p ON p.id=oa.periodo_academico_id
JOIN estados_oferta_academica eo ON eo.id=oa.estado_oferta_id
LEFT JOIN secciones s ON s.oferta_academica_id=oa.id
LEFT JOIN estados_seccion es ON es.id=s.estado_seccion_id
WHERE p.codigo='Q10-P19' ORDER BY oa.id,s.id
SQL) as $r) {
        printf("  oferta=%d (%s/%s) seccion=%s (%s/%s) matriculados=%d elegible_estado=%s\n",
            (int)$r['oferta_id'], $r['oferta'], $r['estado_oferta'],
            $r['seccion_id'] ?? '-', $r['seccion'] ?? '-', $r['estado_seccion'] ?? '-',
            (int)$r['matriculados'],
            $r['seccion_id'] !== null && (int)$r['oferta_permite']===1 && (int)$r['estado_permite']===1 &&
            (int)$r['bandera_permite']===1 && (int)$r['activa']===1 && $r['deleted_at']===null ? 'SI' : 'NO');
    }
    echo "\nMATRICULAS Q10-P19 (solo IDs y cantidades)\n";
    foreach ($db->query(<<<'SQL'
SELECT m.id, m.estudiante_carrera_id, m.oferta_academica_id,
       COUNT(DISTINCT ma.id) AS total_materias,
       COUNT(DISTINCT CASE WHEN ma.activo=1 THEN ma.id END) AS materias_activas
FROM matriculas m JOIN periodos_academicos p ON p.id=m.periodo_academico_id
LEFT JOIN matricula_asignaturas ma ON ma.matricula_id=m.id
WHERE p.codigo='Q10-P19'
GROUP BY m.id,m.estudiante_carrera_id,m.oferta_academica_id ORDER BY m.id
SQL) as $r) {
        printf("  matricula=%d trayectoria=%d oferta=%d materias=%d activas=%d\n",
            (int)$r['id'], (int)$r['estudiante_carrera_id'], (int)$r['oferta_academica_id'],
            (int)$r['total_materias'], (int)$r['materias_activas']);
    }
    echo "\nFIN. No se ejecutaron escrituras ni llamadas externas.\n";
} catch (Throwable $e) {
    fwrite(STDERR, 'ERROR: ' . $e->getMessage() . PHP_EOL);
    exit(1);
}
