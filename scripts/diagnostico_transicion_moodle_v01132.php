<?php
declare(strict_types=1);
/** Orion v0.11.32: diagnóstico académico SOLO LECTURA. Sin cambios en Moodle ni BD. */
use App\Core\Config;
use App\Core\Database;
use Dotenv\Dotenv;

define('BASE_PATH', dirname(__DIR__));
require BASE_PATH . '/vendor/autoload.php';
if (is_file(BASE_PATH . '/.env')) {
    Dotenv::createImmutable(BASE_PATH)->safeLoad();
}

function countRows(PDO $pdo, string $sql, array $params = []): int {
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    return (int)$stmt->fetchColumn();
}

try {
    $pdo = (new Database(new Config($_ENV)))->connection();
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    echo "ORION v0.11.32 | TRANSICION ACADEMICA (SOLO LECTURA)\n";
    echo "Fecha MySQL: " . $pdo->query('SELECT CURRENT_DATE()')->fetchColumn() . "\n";
    echo str_repeat('=', 76) . "\n";

    $periods = ['Q10-P17', 'Q10-P19'];
    $periodStmt = $pdo->prepare(
        'SELECT pa.id, pa.codigo, pa.nombre, pa.fecha_inicio, pa.fecha_fin, ep.codigo AS estado ' .
        'FROM periodos_academicos pa JOIN estados_periodo_academico ep ON ep.id=pa.estado_periodo_id ' .
        'WHERE pa.codigo=? LIMIT 1'
    );
    foreach ($periods as $code) {
        $periodStmt->execute([$code]);
        $period = $periodStmt->fetch(PDO::FETCH_ASSOC);
        if (!$period) {
            echo "\nPeriodo $code: NO ENCONTRADO\n";
            continue;
        }
        echo "\nPeriodo {$period['codigo']} | {$period['nombre']} | {$period['estado']}\n";
        echo "Fechas: {$period['fecha_inicio']} a {$period['fecha_fin']}\n";
        $pid = (int)$period['id'];
        $queries = [
            'Matriculas registradas' => 'SELECT COUNT(*) FROM matriculas WHERE periodo_academico_id=?',
            'Matriculas activas' => 'SELECT COUNT(*) FROM matriculas WHERE periodo_academico_id=? AND activo=1',
            'Matriculas confirmadas/en curso' => "SELECT COUNT(*) FROM matriculas m JOIN estados_matricula em ON em.id=m.estado_matricula_id WHERE m.periodo_academico_id=? AND m.activo=1 AND em.codigo IN ('CONFIRMADA','EN_CURSO')",
            'Estudiantes distintos con matricula' => 'SELECT COUNT(DISTINCT ec.estudiante_id) FROM matriculas m JOIN estudiante_carreras ec ON ec.id=m.estudiante_carrera_id WHERE m.periodo_academico_id=?',
        ];
        foreach ($queries as $label => $sql) {
            printf("  %-39s %d\n", $label . ':', countRows($pdo, $sql, [$pid]));
        }
        $stmt = $pdo->prepare('SELECT em.codigo, COUNT(*) AS total FROM matriculas m JOIN estados_matricula em ON em.id=m.estado_matricula_id WHERE m.periodo_academico_id=? GROUP BY em.codigo ORDER BY total DESC, em.codigo');
        $stmt->execute([$pid]);
        foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
            echo "    Estado matricula {$row['codigo']}: {$row['total']}\n";
        }
    }

    echo "\nPanorama general:\n";
    $summary = [
        'Estudiantes activos (estado catalogo)' => "SELECT COUNT(*) FROM estudiantes e JOIN estados_estudiante ee ON ee.id=e.estado_estudiante_id WHERE e.activo=1 AND e.deleted_at IS NULL AND ee.codigo='ACTIVO'",
        'Estudiantes activos con usuario Orion' => "SELECT COUNT(DISTINCT e.id) FROM estudiantes e JOIN estados_estudiante ee ON ee.id=e.estado_estudiante_id JOIN usuarios u ON u.persona_id=e.persona_id AND u.activo=1 AND u.deleted_at IS NULL WHERE e.activo=1 AND e.deleted_at IS NULL AND ee.codigo='ACTIVO'",
        'Usuarios Orion' => 'SELECT COUNT(*) FROM usuarios',
        'Cuentas institucionales' => 'SELECT COUNT(*) FROM cuentas_institucionales',
    ];
    foreach ($summary as $label => $sql) {
        printf("  %-46s %d\n", $label . ':', countRows($pdo, $sql));
    }
    echo "\nINTERPRETACION: Cero matriculas en el periodo actual indica falta de datos en Orion,\n";
    echo "no una baja academica. No suspender cuentas Moodle con este diagnostico.\n";
    echo "No se ejecutaron escrituras ni llamadas a Moodle/Microsoft 365.\n";
} catch (Throwable $e) {
    fwrite(STDERR, 'ERROR diagnostico: ' . $e->getMessage() . "\n");
    exit(1);
}
