<?php
declare(strict_types=1);
namespace App\Integrations\Moodle;

use PDO;

/** Vista previa no destructiva: periodos -> carreras -> asignaturas. */
final class MoodleAcademicPreview
{
    public function __construct(private PDO $db, private MoodleRestClient $moodle) {}

    public function periods(): array
    {
        return $this->db->query("SELECT p.id, p.codigo, p.nombre, p.fecha_inicio, p.fecha_fin,
            (SELECT COUNT(*) FROM ofertas_academicas o WHERE o.periodo_academico_id=p.id AND o.activo=1) ofertas
            FROM periodos_academicos p WHERE p.deleted_at IS NULL
            ORDER BY p.fecha_inicio DESC, p.id DESC LIMIT 30")->fetchAll(PDO::FETCH_ASSOC);
    }

    public function preview(int $periodId): array
    {
        if ($periodId <= 0) { throw new \InvalidArgumentException('Seleccione un período válido.'); }
        $stmt = $this->db->prepare('SELECT id, codigo, nombre FROM periodos_academicos WHERE id=? AND deleted_at IS NULL');
        $stmt->execute([$periodId]);
        $period = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$period) { throw new \RuntimeException('El período solicitado no existe.'); }

        $stmt = $this->db->prepare("SELECT DISTINCT c.id, c.codigo, c.nombre
            FROM ofertas_academicas o JOIN carreras c ON c.id=o.carrera_id
            WHERE o.periodo_academico_id=? AND o.activo=1 AND c.deleted_at IS NULL
            ORDER BY c.nombre LIMIT 100");
        $stmt->execute([$periodId]);
        $careers = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // Secciones representan cursos impartidos. Múltiples paralelos comparten curso.
        $stmt = $this->db->prepare("SELECT DISTINCT c.id carrera_id, a.id asignatura_id, a.codigo asignatura_codigo, a.nombre asignatura_nombre
            FROM ofertas_academicas o
            JOIN carreras c ON c.id=o.carrera_id
            JOIN secciones s ON s.oferta_academica_id=o.id AND s.activo=1 AND s.deleted_at IS NULL
            JOIN malla_asignaturas ma ON ma.id=s.malla_asignatura_id
            JOIN asignaturas a ON a.id=ma.asignatura_id
            WHERE o.periodo_academico_id=? AND o.activo=1 AND c.deleted_at IS NULL
            ORDER BY c.id, a.nombre LIMIT 500");
        $stmt->execute([$periodId]);
        $subjects = $stmt->fetchAll(PDO::FETCH_ASSOC);

        $categories = $this->moodle->categories();
        $courses = $this->moodle->courses();
        $categoryMap = [];
        foreach ($categories as $cat) {
            if (isset($cat['idnumber']) && $cat['idnumber'] !== '') { $categoryMap[(string)$cat['idnumber']] = $cat; }
        }
        $courseMap = [];
        foreach ($courses as $course) {
            if (isset($course['shortname'])) { $courseMap[(string)$course['shortname']] = $course; }
        }
        $periodKey = 'ORION-P-' . $periodId;
        $periodFound = isset($categoryMap[$periodKey]);
        $rows = [];
        foreach ($careers as $career) {
            $careerKey = 'ORION-P-' . $periodId . '-C-' . $career['id'];
            $careerFound = isset($categoryMap[$careerKey]);
            $items = [];
            foreach ($subjects as $subject) {
                if ((int)$subject['carrera_id'] !== (int)$career['id']) { continue; }
                $courseKey = 'ORION-P' . $periodId . '-C' . $career['id'] . '-A' . $subject['asignatura_id'];
                $items[] = [
                    'name' => $subject['asignatura_nombre'], 'code' => $subject['asignatura_codigo'],
                    'key' => $courseKey, 'exists' => isset($courseMap[$courseKey]),
                ];
            }
            $rows[] = ['career' => $career, 'key' => $careerKey, 'exists' => $careerFound, 'subjects' => $items];
        }
        return ['period' => $period, 'period_key' => $periodKey, 'period_exists' => $periodFound,
            'careers' => $rows, 'subjects_total' => count($subjects),
            'notice' => 'Solo vista previa. No se crean ni actualizan categorías o cursos.'];
    }
}
