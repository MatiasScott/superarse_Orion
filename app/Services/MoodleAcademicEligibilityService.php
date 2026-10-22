<?php

declare(strict_types=1);

namespace App\Services;

use PDO;

/** Evaluacion academica de solo lectura. No concede ni revoca accesos Moodle. */
final class MoodleAcademicEligibilityService
{
    public function __construct(private PDO $db) {}

    public function inspectStudent(int $studentId): array
    {
        $result = [
            'student_id' => $studentId,
            'user_id' => null,
            'eligible' => false,
            'status' => 'DENEGADO',
            'reason_code' => 'NOT_EVALUATED',
            'reason' => '',
            'eligible_enrollments' => [],
        ];
        if ($studentId < 1) {
            return $this->deny($result, 'INVALID_STUDENT', 'Identificador de estudiante invalido.');
        }

        $sql = "SELECT e.id AS student_id, e.activo AS student_active,
                       e.deleted_at AS student_deleted, es.codigo AS student_status,
                       u.id AS user_id, u.activo AS user_active,
                       u.deleted_at AS user_deleted, eu.codigo AS user_status
                  FROM estudiantes e
                  JOIN estados_estudiante es ON es.id=e.estado_estudiante_id
                  LEFT JOIN usuarios u ON u.persona_id=e.persona_id
                  LEFT JOIN estados_usuario eu ON eu.id=u.estado_usuario_id
                 WHERE e.id=:student_id LIMIT 1";
        $stmt = $this->db->prepare($sql);
        $stmt->execute(['student_id' => $studentId]);
        $student = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$student) {
            return $this->deny($result, 'STUDENT_NOT_FOUND', 'Estudiante no encontrado.');
        }
        $result['user_id'] = $student['user_id'] !== null ? (int)$student['user_id'] : null;
        if ((int)$student['student_active'] !== 1 || $student['student_deleted'] !== null || $student['student_status'] !== 'ACTIVO') {
            return $this->deny($result, 'STUDENT_NOT_ACTIVE', 'El estudiante no tiene estado academico ACTIVO.');
        }
        if (!$result['user_id'] || (int)$student['user_active'] !== 1 || $student['user_deleted'] !== null || $student['user_status'] !== 'ACTIVO') {
            return $this->deny($result, 'USER_NOT_ACTIVE', 'El usuario institucional no esta activo en Orion.');
        }

        $sql = "SELECT DISTINCT m.id AS enrollment_id, m.numero_matricula,
                       ec.id AS trajectory_id, ec.carrera_id,
                       pa.id AS period_id, pa.codigo AS period_code,
                       em.codigo AS enrollment_status
                  FROM estudiante_carreras ec
                  JOIN estados_trayectoria_academica et ON et.id=ec.estado_trayectoria_id
                  JOIN matriculas m ON m.estudiante_carrera_id=ec.id
                  JOIN estados_matricula em ON em.id=m.estado_matricula_id
                  JOIN periodos_academicos pa ON pa.id=m.periodo_academico_id
                  JOIN estados_periodo_academico ep ON ep.id=pa.estado_periodo_id
                 WHERE ec.estudiante_id=:student_id
                   AND ec.activo=1 AND ec.deleted_at IS NULL AND et.codigo='ACTIVA'
                   AND m.activo=1 AND em.codigo IN ('CONFIRMADA','EN_CURSO')
                   AND pa.activo=1 AND pa.deleted_at IS NULL AND ep.codigo='EN_CURSO'
                   AND CURRENT_DATE() BETWEEN pa.fecha_inicio AND pa.fecha_fin
                   AND EXISTS (
                       SELECT 1 FROM matricula_asignaturas ma
                       JOIN estados_matricula_asignatura ema ON ema.id=ma.estado_matricula_asignatura_id
                       JOIN secciones s ON s.id=ma.seccion_id
                       WHERE ma.matricula_id=m.id AND ma.activo=1
                         AND s.activo=1 AND s.deleted_at IS NULL
                         AND ema.codigo IN ('MATRICULADA','EN_CURSO')
                   )
                 ORDER BY pa.fecha_inicio DESC, m.id DESC";
        $stmt = $this->db->prepare($sql);
        $stmt->execute(['student_id' => $studentId]);
        $enrollments = $stmt->fetchAll(PDO::FETCH_ASSOC);
        if (!$enrollments) {
            return $this->deny($result, 'NO_ACTIVE_ENROLLMENT', 'No existe matricula academica vigente y aprobada.');
        }
        $result['eligible'] = true;
        $result['status'] = 'PERMITIDO';
        $result['reason_code'] = 'ACTIVE_ENROLLMENT';
        $result['reason'] = 'El estudiante tiene matricula vigente y aprobada.';
        $result['eligible_enrollments'] = $enrollments;
        return $result;
    }

    private function deny(array $result, string $code, string $reason): array
    {
        $result['eligible'] = false;
        $result['status'] = 'DENEGADO';
        $result['reason_code'] = $code;
        $result['reason'] = $reason;
        return $result;
    }
}
