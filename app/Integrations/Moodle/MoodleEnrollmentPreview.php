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
}
