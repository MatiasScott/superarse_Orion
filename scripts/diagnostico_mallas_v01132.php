<?php
declare(strict_types=1);
/** Orion v0.11.32 Fase 2B - consulta exclusivamente de lectura. */
use App\Core\Config;
use App\Core\Database;
use Dotenv\Dotenv;

define('BASE_PATH', dirname(__DIR__));
require BASE_PATH . '/vendor/autoload.php';
if (is_file(BASE_PATH . '/.env')) {
    Dotenv::createImmutable(BASE_PATH)->safeLoad();
}

try {
    $pdo = (new Database(new Config($_ENV)))->connection();
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
    echo "ORION v0.11.32 - FASE 2B | MALLAS Y CONCILIACION (SOLO LECTURA)\n";
    echo str_repeat('=', 76) . "\n";
    $sql = <<<'SQL'
SELECT c.id AS carrera_id, c.codigo AS carrera_codigo, c.nombre AS carrera,
       mc.id AS malla_id, mc.codigo AS malla_codigo, mc.nombre AS malla,
       mc.version, em.codigo AS estado_malla, mc.fecha_inicio_vigencia,
       mc.fecha_fin_vigencia, mc.activo AS malla_activa,
       COUNT(DISTINCT ec.id) AS trayectorias_asociadas
FROM carreras c
LEFT JOIN mallas_curriculares mc ON mc.carrera_id = c.id AND mc.deleted_at IS NULL
LEFT JOIN estados_malla em ON em.id = mc.estado_malla_id
LEFT JOIN estudiante_carreras ec ON ec.malla_id = mc.id AND ec.deleted_at IS NULL
WHERE c.deleted_at IS NULL
GROUP BY c.id, c.codigo, c.nombre, mc.id, mc.codigo, mc.nombre,
         mc.version, em.codigo, mc.fecha_inicio_vigencia,
         mc.fecha_fin_vigencia, mc.activo
ORDER BY c.nombre, mc.fecha_inicio_vigencia DESC, mc.id DESC
SQL;
    foreach ($pdo->query($sql) as $r) {
        printf("Carrera #%d: %s [%s]\n", (int)$r['carrera_id'], $r['carrera'], $r['carrera_codigo']);
        if ($r['malla_id'] === null) {
            echo "  SIN MALLA REGISTRADA\n";
        } else {
            printf("  Malla #%d: %s | version=%s | estado=%s | activa=%s | vigencia=%s a %s | trayectorias=%d\n",
                (int)$r['malla_id'], $r['malla_codigo'], $r['version'] ?? '-',
                $r['estado_malla'] ?? '-', (string)$r['malla_activa'],
                $r['fecha_inicio_vigencia'], $r['fecha_fin_vigencia'] ?? 'sin fin',
                (int)$r['trayectorias_asociadas']);
        }
    }
    echo "\nRESUMEN DE IDENTIFICACIONES (SIN MOSTRAR DATOS PERSONALES)\n";
    $checks = [
        'personas con identificacion duplicada' => <<<'SQL'
SELECT COUNT(*) FROM (
  SELECT tipo_identificacion_id, numero_identificacion
  FROM personas WHERE deleted_at IS NULL
  GROUP BY tipo_identificacion_id, numero_identificacion HAVING COUNT(*) > 1
) x
SQL,
        'estudiantes sin trayectoria' => <<<'SQL'
SELECT COUNT(*) FROM estudiantes e
WHERE e.deleted_at IS NULL AND NOT EXISTS (
 SELECT 1 FROM estudiante_carreras ec
 WHERE ec.estudiante_id=e.id AND ec.deleted_at IS NULL
)
SQL,
        'trayectorias sin malla valida' => <<<'SQL'
SELECT COUNT(*) FROM estudiante_carreras ec
LEFT JOIN mallas_curriculares mc ON mc.id=ec.malla_id AND mc.deleted_at IS NULL
WHERE ec.deleted_at IS NULL AND mc.id IS NULL
SQL,
    ];
    foreach ($checks as $label => $query) {
        printf("  %-45s %d\n", $label . ':', (int)$pdo->query($query)->fetchColumn());
    }
    echo "\nFIN. No se ejecutaron escrituras ni llamadas a Moodle o Microsoft 365.\n";
} catch (Throwable $e) {
    fwrite(STDERR, "ERROR: " . $e->getMessage() . "\n");
    exit(1);
}
