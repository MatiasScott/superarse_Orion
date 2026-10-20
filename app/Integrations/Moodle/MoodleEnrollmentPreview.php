<?php
declare(strict_types=1);
namespace App\Integrations\Moodle;

use PDO;

/** Vista previa local, estrictamente de solo lectura. No concede acceso Moodle. */
final class MoodleEnrollmentPreview
{
    public function __construct(private PDO $db) {}

    /** Estados habilitados oficialmente para cursar; excluye finalizadas y anuladas. */
    public function forSections(array $sectionIds): array
    {
        $sectionIds = array_values(array_unique(array_filter(array_map('intval', $sectionIds), static fn(int $id): bool => $id > 0)));
        if (!$sectionIds) return [];
        $placeholders = implode(',', array_fill(0, count($sectionIds), '?'));
        $sql = "SELECT ma.seccion_id, em.codigo AS estado_matricula,
                       ema.codigo AS estado_asignatura, COUNT(*) AS total
                  FROM matricula_asignaturas ma
                  JOIN matriculas m ON m.id = ma.matricula_id
                  JOIN estados_matricula em ON em.id = m.estado_matricula_id
                  JOIN estados_matricula_asignatura ema ON ema.id = ma.estado_matricula_asignatura_id
                  JOIN secciones s ON s.id = ma.seccion_id
                 WHERE ma.seccion_id IN ($placeholders)
                   AND ma.activo = 1 AND m.activo = 1
                   AND s.activo = 1 AND s.deleted_at IS NULL
                 GROUP BY ma.seccion_id, em.codigo, ema.codigo";
        $stmt = $this->db->prepare($sql);
        $stmt->execute($sectionIds);
        $result = [];
        foreach ($sectionIds as $id) $result[$id] = ['eligible' => 0, 'excluded' => 0, 'total' => 0, 'reasons' => []];
        foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
            $id = (int)$row['seccion_id'];
            $n = (int)$row['total'];
            $status = (string)$row['estado_matricula'];
            $subject = (string)$row['estado_asignatura'];
            $result[$id]['total'] += $n;
            // CONFIRMADA y EN_CURSO representan matrícula académica vigente aprobada.
            // Excluir asignaturas retiradas/anuladas incluso si la matrícula general continúa vigente.
            if (in_array($status, ['CONFIRMADA', 'EN_CURSO'], true)
                && in_array($subject, ['MATRICULADA', 'EN_CURSO'], true)) {
                $result[$id]['eligible'] += $n;
            } else {
                $result[$id]['excluded'] += $n;
                $reason = $status.' / '.$subject;
                $result[$id]['reasons'][$reason] = ($result[$id]['reasons'][$reason] ?? 0) + $n;
            }
        }
        return $result;
    }
    /** Candidatos aprobados, con mapeo local por ID; nunca deduce usuarios por nombre. */
    public function studentsForSections(array $sectionIds): array
    {
        $ids = array_values(array_unique(array_filter(array_map('intval', $sectionIds), static fn(int $v): bool => $v > 0)));
        if (!$ids) return [];
        $marks = implode(',', array_fill(0, count($ids), '?'));
        $sql = "SELECT ma.seccion_id, e.id AS estudiante_id, e.codigo_estudiante,
                       u.id AS usuario_id, ci.username AS institutional_username, ci.email_institucional, um.moodle_user_id, um.username_moodle,
                       um.activo AS mapeo_activo, um.suspendido
                  FROM matricula_asignaturas ma
                  JOIN matriculas m ON m.id=ma.matricula_id
                  JOIN estados_matricula em ON em.id=m.estado_matricula_id
                  JOIN estados_matricula_asignatura ema ON ema.id=ma.estado_matricula_asignatura_id
                  JOIN estudiante_carreras ec ON ec.id=m.estudiante_carrera_id
                  JOIN estudiantes e ON e.id=ec.estudiante_id
                  JOIN secciones s ON s.id=ma.seccion_id
                  LEFT JOIN usuarios u ON u.persona_id=e.persona_id AND u.activo=1 AND u.deleted_at IS NULL
                  LEFT JOIN cuentas_institucionales ci ON ci.id=(SELECT ci2.id FROM cuentas_institucionales ci2 WHERE ci2.usuario_id=u.id AND ci2.activo=1 AND ci2.deleted_at IS NULL ORDER BY ci2.id DESC LIMIT 1)
                  LEFT JOIN usuario_moodle_mapeos um ON um.usuario_id=u.id AND um.activo=1
                 WHERE ma.seccion_id IN ($marks) AND ma.activo=1 AND m.activo=1
                   AND s.activo=1 AND s.deleted_at IS NULL AND e.activo=1 AND e.deleted_at IS NULL
                   AND em.codigo IN ('CONFIRMADA','EN_CURSO')
                   AND ema.codigo IN ('MATRICULADA','EN_CURSO')
                 ORDER BY ma.seccion_id,e.codigo_estudiante,um.id";
        $stmt=$this->db->prepare($sql);
        $stmt->execute($ids);
        $result=[];
        foreach ($ids as $id) $result[$id]=[];
        foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
            $section=(int)$row['seccion_id'];
            $student=(int)$row['estudiante_id'];
            if (!isset($result[$section][$student])) {
                $result[$section][$student]=[
                    'student_id'=>$student,'code'=>(string)$row['codigo_estudiante'],
                    'user_id'=>(int)($row['usuario_id'] ?? 0),'institutional_username'=>(string)($row['institutional_username'] ?? ''),'institutional_email'=>(string)($row['email_institucional'] ?? ''),'mappings'=>[]
                ];
            }
            if ((int)($row['moodle_user_id'] ?? 0)>0) {
                $result[$section][$student]['mappings'][]=[
                    'id'=>(int)$row['moodle_user_id'],
                    'username'=>(string)$row['username_moodle'],
                    'suspended'=>(bool)$row['suspendido'],
                ];
            }
        }
        foreach ($result as &$students) $students=array_values($students);
        unset($students);
        return $result;
    }

}
