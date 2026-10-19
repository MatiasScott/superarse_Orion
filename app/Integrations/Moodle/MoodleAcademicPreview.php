<?php
declare(strict_types=1);
namespace App\Integrations\Moodle;
use PDO;

/** Conciliación no destructiva de categorías y cursos; sin llamadas de escritura. */
final class MoodleAcademicPreview
{
    public function __construct(private PDO $db, private MoodleRestClient $moodle) {}

    public function periods(): array
    {
        return $this->db->query("SELECT p.id,p.codigo,p.nombre,p.fecha_inicio,p.fecha_fin,
          (SELECT COUNT(*) FROM ofertas_academicas o WHERE o.periodo_academico_id=p.id AND o.activo=1) ofertas
          FROM periodos_academicos p WHERE p.deleted_at IS NULL
          ORDER BY p.fecha_inicio DESC,p.id DESC LIMIT 30")->fetchAll(PDO::FETCH_ASSOC);
    }

    private static function norm(string $value): string
    {
        $value = mb_strtolower(trim($value), 'UTF-8');
        $value = strtr($value, ['á'=>'a','é'=>'e','í'=>'i','ó'=>'o','ú'=>'u','ü'=>'u','ñ'=>'n']);
        return trim(preg_replace('/[^a-z0-9]+/u', ' ', $value) ?? $value);
    }

    /** Nombre académico legible: elimina únicamente el sufijo técnico de Orion/Q10.
     * Ejemplo: Administración del Talento Humano y Nómina-ADM-MN-N1
     *          -> Administración del Talento Humano y Nómina.
     * El nombre original y el código permanecen intactos en la base de datos.
     */
    private static function displaySubjectName(string $name, string $code): string
    {
        $name = trim($name);
        $parts = array_values(array_filter(explode('-', strtoupper(trim($code))), static fn(string $v): bool => $v !== ''));
        // Q10: UP01-04-ADM-MN -> sufijo -ADM-MN-N1
        if (count($parts) >= 4) {
            $tail = implode('-', array_slice($parts, 2));
            $pattern = '/-' . preg_quote($tail, '/') . '-N[0-9]+\s*$/iu';
            $clean = preg_replace($pattern, '', $name);
            if ($clean !== null && $clean !== $name && trim($clean) !== '') {
                return trim($clean);
            }
        }
        // Variantes importadas: sufijo final tipo -ADM-MN-N1, sin modificar otros nombres.
        $clean = preg_replace('/-(?:[A-Z]{2,}(?:-[A-Z]{2,})+)-N[0-9]+\s*$/iu', '', $name);
        return trim((string)$clean) !== '' ? trim((string)$clean) : $name;
    }

    public function preview(int $periodId): array
    {
        $stmt = $this->db->prepare('SELECT id,codigo,nombre FROM periodos_academicos WHERE id=? AND deleted_at IS NULL');
        $stmt->execute([$periodId]);
        $period = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$period) { throw new \RuntimeException('Período no encontrado.'); }

        $stmt = $this->db->prepare("SELECT o.id oferta_id,o.sede_id,o.modalidad_academica_id,
          c.id carrera_id,c.nombre carrera,c.codigo carrera_codigo,
          s.nombre sede, s.codigo sede_codigo,
          e.codigo escuela, e.nombre escuela_nombre,
          mo.nombre modalidad, mo.codigo modalidad_codigo,
          COALESCE(r.requiere_modalidad,0) requiere_modalidad,
          na.id nivel_id,na.nombre nivel,na.orden_nivel,
          a.id asignatura_id,a.nombre asignatura,a.codigo asignatura_codigo
          FROM ofertas_academicas o
          JOIN carreras c ON c.id=o.carrera_id AND c.deleted_at IS NULL
          LEFT JOIN sedes s ON s.id=o.sede_id
          LEFT JOIN carrera_escuela_moodle ce ON ce.carrera_id=c.id
          LEFT JOIN escuelas_academicas e ON e.id=ce.escuela_id
          LEFT JOIN modalidades_academicas mo ON mo.id=o.modalidad_academica_id
          LEFT JOIN modalidad_categoria_moodle_reglas r ON r.carrera_id=c.id AND r.sede_id=o.sede_id
          JOIN secciones sec ON sec.oferta_academica_id=o.id AND sec.activo=1 AND sec.deleted_at IS NULL
          JOIN malla_asignaturas ma ON ma.id=sec.malla_asignatura_id
          JOIN niveles_academicos na ON na.id=ma.nivel_academico_id
          JOIN asignaturas a ON a.id=ma.asignatura_id
          WHERE o.periodo_academico_id=? AND o.activo=1
          GROUP BY o.id,c.id,s.id,e.id,mo.id,r.requiere_modalidad,na.id,a.id
          ORDER BY s.nombre,e.codigo,c.nombre,mo.nombre,na.orden_nivel,a.nombre LIMIT 1500");
        $stmt->execute([$periodId]);
        $subjects = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $categories = $this->moodle->categories();
        $courses = $this->moodle->courses();
        $byParent = [];
        foreach ($categories as $cat) { $byParent[(int)($cat['parent'] ?? 0)][] = $cat; }
        $root = [];
        foreach ($byParent[0] ?? [] as $cat) {
            if (self::norm((string)$cat['name']) === 'superarse') { $root[] = $cat; }
        }
        $warnings = [];
        if (count($root) !== 1) { $warnings[] = 'No se encontró una única categoría raíz Superarse; no se puede identificar una ruta segura.'; }
        $rootId = count($root) === 1 ? (int)$root[0]['id'] : null;
        $periodCandidates = $rootId !== null ? $this->children($byParent, $rootId, (string)$period['nombre']) : [];
        $periodCategory = count($periodCandidates) === 1 ? $periodCandidates[0] : null;
        if (count($periodCandidates) > 1) { $warnings[] = 'Hay varias categorías de período con el mismo nombre normalizado.'; }
        $rows = [];
        foreach ($subjects as $subject) {
            $segments = [
                ['label'=>'Período', 'name'=>(string)$period['nombre']],
                ['label'=>'Campus', 'name'=>(string)($subject['sede'] ?? ''), 'aliases'=>['Campus '.(string)($subject['sede'] ?? '')]],
                ['label'=>'Escuela', 'name'=>(string)($subject['escuela'] ?? '')],
                ['label'=>'Carrera', 'name'=>(string)$subject['carrera']],
            ];
            $blocked = [];
            if (empty($subject['sede'])) { $blocked[] = 'Oferta sin campus'; }
            if (empty($subject['escuela'])) { $blocked[] = 'Carrera sin escuela asignada'; }
            if ((int)$subject['requiere_modalidad'] === 1) {
                if (empty($subject['modalidad'])) { $blocked[] = 'Oferta sin modalidad'; }
                else { $segments[] = ['label'=>'Modalidad','name'=>(string)$subject['modalidad']]; }
            }
            $segments[] = ['label'=>'Nivel','name'=>(string)$subject['nivel']];
            $parentId = $rootId;
            foreach ($segments as &$segment) {
                $segment['moodle_id'] = null;
                $segment['status'] = 'pendiente';
                if ($parentId === null) { continue; }
                $matches = $this->children($byParent, $parentId, $segment['name'], $segment['aliases'] ?? []);
                if (count($matches) === 1) {
                    $parentId = (int)$matches[0]['id'];
                    $segment['moodle_id'] = $parentId;
                    $segment['status'] = 'existente';
                    $segment['moodle_name'] = (string)$matches[0]['name'];
                } elseif (count($matches) > 1) {
                    $blocked[] = 'Categorías ambiguas: '.$segment['name'];
                    $parentId = null;
                    $segment['status'] = 'ambiguo';
                } else { $parentId = null; $segment['status'] = 'no_encontrado'; }
            }
            unset($segment);
            $key = 'ORION-O'.$subject['oferta_id'].'-A'.$subject['asignatura_id'];
            $exact = []; $suggestions = [];
            $displayName = self::displaySubjectName((string)$subject['asignatura'], (string)$subject['asignatura_codigo']);
            $subjectName = self::norm($displayName);
            $subjectCode = self::norm((string)$subject['asignatura_codigo']);
            foreach ($courses as $course) {
                $courseId = (int)($course['id'] ?? 0);
                $courseCategory = (int)($course['categoryid'] ?? 0);
                if ($courseId <= 0) { continue; }
                if ((string)($course['shortname'] ?? '') === $key || (string)($course['idnumber'] ?? '') === $key) {
                    $exact[] = $course;
                    continue;
                }
                $fullName = (string)($course['fullname'] ?? '');
                $shortName = (string)($course['shortname'] ?? '');
                $idNumber = (string)($course['idnumber'] ?? '');
                $nameMatch = self::norm($fullName) === $subjectName;
                $codeMatch = $subjectCode !== '' && ($subjectCode === self::norm($idNumber) || $subjectCode === self::norm($shortName));
                if (!$nameMatch && !$codeMatch) { continue; }
                $sameCategory = $parentId !== null && $courseCategory === $parentId;
                $suggestions[] = [
                    'id'=>$courseId, 'name'=>$fullName, 'category'=>$courseCategory,
                    'same_category'=>$sameCategory, 'name_match'=>$nameMatch, 'code_match'=>$codeMatch,
                    'shortname'=>$shortName, 'idnumber'=>$idNumber,
                ];
            }
            usort($suggestions, static function (array $a, array $b): int {
                $scoreA = ((int)$a['same_category'] * 4) + ((int)$a['code_match'] * 2) + (int)$a['name_match'];
                $scoreB = ((int)$b['same_category'] * 4) + ((int)$b['code_match'] * 2) + (int)$b['name_match'];
                return ($scoreB <=> $scoreA) ?: ($a['id'] <=> $b['id']);
            });
            $local = array_values(array_filter($suggestions, static fn(array $s): bool => $s['same_category']));
            $courseStatus = count($exact) === 1 ? 'clave_exacta' : (
                count($local) === 1 ? 'coincidencia_en_nivel' : (
                count($local) > 1 ? 'ambiguo_en_nivel' : (count($suggestions) ? 'coincidencia_fuera_de_nivel' : 'no_identificado')
            ));
            $rows[] = [
                'subject'=>$subject, 'display_name'=>$displayName, 'segments'=>$segments,'key'=>$key,'blocked'=>$blocked,
                'course_id'=>count($exact) === 1 ? (int)$exact[0]['id'] : null,
                'suggestions'=>array_slice($suggestions,0,15), 'suggestion_total'=>count($suggestions),
                'course_status'=>$courseStatus, 'category_id'=>$parentId,
            ];
        }
        return ['period'=>$period,'root_id'=>$rootId,'period_category_id'=>$periodCategory['id'] ?? null,
            'category_count'=>count($categories),'course_count'=>count($courses),
            'rows'=>$rows,'warnings'=>$warnings,'notice'=>'Solo lectura. Las sugerencias no constituyen vinculaciones y no se modifica Moodle ni Orion.'];
    }

    private function children(array $byParent, int $parent, string $name, array $aliases = []): array
    {
        if (trim($name) === '') { return []; }
        $expected = array_unique(array_map([self::class, 'norm'], array_merge([$name], $aliases)));
        return array_values(array_filter($byParent[$parent] ?? [],
            static fn(array $c): bool => in_array(self::norm((string)($c['name'] ?? '')), $expected, true)));
    }
}
