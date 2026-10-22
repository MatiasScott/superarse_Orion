<?php

declare(strict_types=1);

/** Diagnostico de solo lectura. No consulta ni modifica Moodle. */

use App\Core\Config;
use App\Core\Database;
use App\Services\MoodleAcademicEligibilityService;
use Dotenv\Dotenv;

define('BASE_PATH', dirname(__DIR__));
require BASE_PATH . '/vendor/autoload.php';
if (is_file(BASE_PATH . '/.env')) {
    Dotenv::createImmutable(BASE_PATH)->safeLoad();
}

try {
    $db = (new Database(new Config($_ENV)))->connection();
    $service = new MoodleAcademicEligibilityService($db);
    $ids = array_slice(array_values(array_filter(array_map('intval', array_slice($argv, 1)), static fn(int $v): bool => $v > 0)), 0, 30);
    if (!$ids) {
        $sql = "SELECT e.id FROM estudiantes e JOIN usuarios u ON u.persona_id=e.persona_id WHERE e.deleted_at IS NULL ORDER BY e.id LIMIT 30";
        $ids = array_map('intval', $db->query($sql)->fetchAll(PDO::FETCH_COLUMN));
    }
    if (!$ids) {
        echo "No existen estudiantes con usuario Orion para evaluar.\n";
        exit(0);
    }
    echo "ORION v0.11.31 - DIAGNOSTICO ACADEMICO (SOLO LECTURA)\n";
    echo 'Fecha MySQL: ' . $db->query('SELECT CURRENT_DATE()')->fetchColumn() . "\n";
    foreach ($ids as $studentId) {
        $result = $service->inspectStudent($studentId);
        printf("Estudiante ID %d | %s | %s\n", $studentId, $result['status'], $result['reason_code']);
        echo 'Motivo: ' . $result['reason'] . "\n";
        foreach ($result['eligible_enrollments'] as $enrollment) {
            printf("  Matricula: %s | Periodo: %s | Estado: %s\n", $enrollment['numero_matricula'], $enrollment['period_code'], $enrollment['enrollment_status']);
        }
        echo str_repeat('-', 65) . "\n";
    }
} catch (Throwable $e) {
    fwrite(STDERR, 'Error de diagnostico: ' . $e->getMessage() . "\n");
    exit(1);
}
