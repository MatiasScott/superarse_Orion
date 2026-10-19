<?php
declare(strict_types=1);
namespace App\Integrations\Moodle;

use PDO;
use RuntimeException;

/** Una creación por confirmación, con nueva conciliación en vivo y sin matricular usuarios. */
final class MoodleCourseSync
{
    public function __construct(private PDO $db, private MoodleRestClient $moodle) {}

    public function create(array $preview, int $periodId, int $offerId, int $subjectId, ?int $actor): int
    {
        if ($preview['warnings']) throw new RuntimeException('El inventario Moodle requiere revisión.');
        $target = null;
        foreach ($preview['rows'] as $row) {
            if ((int)$row['subject']['oferta_id'] === $offerId && (int)$row['subject']['asignatura_id'] === $subjectId) {
                $target = $row; break;
            }
        }
        if (!$target) throw new RuntimeException('La asignatura no pertenece a la oferta del período.');
        if ($target['blocked'] || !$target['category_id'] || $target['saved_mapping'] ||
            $target['exact_count'] !== 0 || $target['any_candidate_count'] !== 0) {
            throw new RuntimeException('Existen coincidencias, vinculaciones o categorías sin resolver. Revise antes de crear.');
        }
        $name = trim((string)$target['display_name']);
        $key = (string)$target['key'];
        if ($name === '' || $key === '') throw new RuntimeException('Nombre o clave de curso inválidos.');
        $courses = $this->moodle->courses();
        foreach ($courses as $course) {
            if ((string)($course['idnumber'] ?? '') === $key || (string)($course['shortname'] ?? '') === $key) {
                throw new RuntimeException('La clave de curso ya existe en Moodle.');
            }
            if ((int)($course['categoryid'] ?? 0) === (int)$target['category_id'] &&
                $this->normalize((string)($course['fullname'] ?? '')) === $this->normalize($name)) {
                throw new RuntimeException('Ya existe un curso con el mismo nombre dentro del nivel.');
            }
        }
        $stmt = $this->db->prepare('SELECT moodle_course_id FROM orion_moodle_vinculos_asignatura WHERE oferta_academica_id=? AND asignatura_id=?');
        $stmt->execute([$offerId,$subjectId]);
        if ($stmt->fetchColumn()) throw new RuntimeException('La asignatura ya está vinculada en Orion.');
        $period = $this->db->prepare('SELECT fecha_inicio,fecha_fin FROM periodos_academicos WHERE id=? AND deleted_at IS NULL');
        $period->execute([$periodId]);
        $dates = $period->fetch(PDO::FETCH_ASSOC);
        if (!$dates) throw new RuntimeException('Período inexistente.');
        $start = !empty($dates['fecha_inicio']) ? strtotime((string)$dates['fecha_inicio'].' 00:00:00') : false;
        $end = !empty($dates['fecha_fin']) ? strtotime((string)$dates['fecha_fin'].' 23:59:59') : false;
        $response = $this->moodle->createCourse($name, $key, $key, (int)$target['category_id'], $start ?: 0, $end ?: 0);
        $id = (int)$response['id'];
        // Moodle no participa en la transacción SQL: registrar resultado remoto antes de cualquier otra operación.
        try {
            $stmt = $this->db->prepare('INSERT INTO orion_moodle_vinculos_asignatura (oferta_academica_id, asignatura_id, periodo_academico_id, moodle_course_id, moodle_category_id, fullname_moodle, shortname_moodle, idnumber_moodle, creado_por) VALUES (?,?,?,?,?,?,?,?,?)');
            $stmt->execute([$offerId,$subjectId,$periodId,$id,(int)$target['category_id'],$name,$key,$key,$actor]);
            $log = $this->db->prepare('INSERT INTO orion_moodle_curso_sync_log (periodo_academico_id,oferta_academica_id,asignatura_id,moodle_course_id,moodle_category_id,nombre,creado_por) VALUES (?,?,?,?,?,?,?)');
            $log->execute([$periodId,$offerId,$subjectId,$id,(int)$target['category_id'],$name,$actor]);
        } catch (\Throwable $e) {
            throw new RuntimeException('Moodle creó el curso #'.$id.' pero falló su registro en Orion. NO repita la operación: concilie el curso antes de continuar.', 0, $e);
        }
        return $id;
    }

    private function normalize(string $name): string
    {
        $name = mb_strtolower(trim($name), 'UTF-8');
        $name = strtr($name, ['á'=>'a','é'=>'e','í'=>'i','ó'=>'o','ú'=>'u','ü'=>'u','ñ'=>'n']);
        return trim(preg_replace('/[^a-z0-9]+/u', ' ', $name) ?? $name);
    }
}
