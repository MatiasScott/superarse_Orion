<?php
declare(strict_types=1);
namespace App\Controllers\Admin;

use App\Core\Request;
use App\Core\Response;
use App\Core\Csrf;
use App\Core\Session;
use App\Core\View;
use App\Core\Config;
use App\Core\Database;
use App\Integrations\Moodle\MoodleRestClient;
use App\Integrations\Moodle\MoodleAcademicPreview;
use App\Integrations\Moodle\MoodleCategorySync;
use App\Integrations\Moodle\MoodleCourseSync;
use App\Integrations\Moodle\MoodleEnrollmentPreview;
use App\Services\AccessService;
use Throwable;

final class MoodleIntegrationController
{
    public function link(Request $request): never
    {
        AccessService::require('tic.cuentas.ver');
        if (!Csrf::validate((string)$request->input('_csrf'))) Response::abort(419, 'CSRF inválido.');
        $periodId = (int)$request->input('periodo');
        $offerId = (int)$request->input('oferta_id');
        $subjectId = (int)$request->input('asignatura_id');
        $courseId = (int)$request->input('moodle_course_id');
        if ($periodId <= 0 || $offerId <= 0 || $subjectId <= 0 || $courseId <= 0) Response::abort(422, 'Datos de vinculación inválidos.');
        try {
            $db = (new Database(new Config($_ENV)))->connection();
            $client = new MoodleRestClient($_ENV);
            $academic = new MoodleAcademicPreview($db, $client);
            // Revalidar en vivo: nunca confiar en nombres, categorías ni IDs enviados por el navegador.
            $preview = $academic->preview($periodId);
            $target = null;
            foreach ($preview['rows'] as $row) {
                if ((int)$row['subject']['oferta_id'] === $offerId && (int)$row['subject']['asignatura_id'] === $subjectId) {
                    $target = $row;
                    break;
                }
            }
            if (!$target || $target['saved_mapping'] || $target['blocked'] || !$target['category_id']) Response::abort(409, 'La asignatura ya está vinculada o la ruta requiere revisión.');
            $allowed = false;
            foreach ($target['suggestions'] as $candidate) {
                if ((int)$candidate['id'] === $courseId && $candidate['same_category'] && $candidate['name_match']) $allowed = true;
            }
            if (!$allowed) Response::abort(409, 'El curso ya no coincide con el nombre y nivel esperados.');
            $remote = null;
            foreach ($client->courses() as $course) {
                if ((int)($course['id'] ?? 0) === $courseId) { $remote = $course; break; }
            }
            if (!$remote || (int)$remote['categoryid'] !== (int)$target['category_id']) Response::abort(409, 'El curso cambió de categoría o ya no existe.');
            $stmt = $db->prepare('INSERT INTO orion_moodle_vinculos_asignatura (oferta_academica_id, asignatura_id, periodo_academico_id, moodle_course_id, moodle_category_id, fullname_moodle, shortname_moodle, idnumber_moodle, creado_por) VALUES (?,?,?,?,?,?,?,?,?)');
            $user = (array)Session::get('auth_user', []);
            $actor = isset($user['id']) ? (int)$user['id'] : null;
            $stmt->execute([$offerId, $subjectId, $periodId, $courseId, (int)$remote['categoryid'], (string)$remote['fullname'], (string)$remote['shortname'], (string)($remote['idnumber'] ?? ''), $actor]);
            Session::set('moodle_link_notice', 'Vinculación guardada: curso Moodle #'.$courseId.'.');
        } catch (\PDOException $e) {
            if ($e->getCode() === '23000') Response::abort(409, 'La asignatura o el curso Moodle ya tienen una vinculación.');
            throw $e;
        }
        Response::redirect('/admin/tic/moodle?periodo='.$periodId);
    }

    public function syncCategories(Request $request): never
    {
        AccessService::require('tic.cuentas.aprobar');
        if (!Csrf::validate((string)$request->input('_csrf'))) Response::abort(419, 'CSRF inválido.');
        if (!filter_var($_ENV['MOODLE_SYNC_ENABLED'] ?? false, FILTER_VALIDATE_BOOL)) {
            Response::abort(403, 'Habilite MOODLE_SYNC_ENABLED=true para sincronizar categorías.');
        }
        $periodId = (int)$request->input('periodo');
        if ($periodId < 1 || (string)$request->input('confirmacion') !== 'SINCRONIZAR') {
            Response::abort(422, 'Confirmación de sincronización inválida.');
        }
        try {
            $db = (new Database(new Config($_ENV)))->connection();
            $client = new MoodleRestClient($_ENV);
            $academic = new MoodleAcademicPreview($db, $client);
            $preview = $academic->preview($periodId);
            $sync = new MoodleCategorySync($db, $client);
            $user = (array)Session::get('auth_user', []);
            $result = $sync->execute($preview, $periodId, isset($user['id']) ? (int)$user['id'] : null);
            Session::set('moodle_link_notice', 'Categorías: '.$result['created'].' creadas y '.$result['reused'].' reutilizadas. No se modificaron cursos.');
        } catch (Throwable $e) {
            // Puede existir una sincronización parcial; cada reintento vuelve a consultar Moodle.
            Session::set('moodle_link_notice', 'Sincronización interrumpida: '.$e->getMessage().' Revise Moodle antes de reintentar.');
        }
        Response::redirect('/admin/tic/moodle?periodo='.$periodId);
    }

    public function createCourse(Request $request): never
    {
        AccessService::require('tic.cuentas.aprobar');
        if (!Csrf::validate((string)$request->input('_csrf'))) Response::abort(419, 'CSRF inválido.');
        if (!filter_var($_ENV['MOODLE_SYNC_ENABLED'] ?? false, FILTER_VALIDATE_BOOL)) Response::abort(403, 'Sincronización deshabilitada.');
        $periodId = (int)$request->input('periodo');
        $offerId = (int)$request->input('oferta_id');
        $subjectId = (int)$request->input('asignatura_id');
        if ($periodId < 1 || $offerId < 1 || $subjectId < 1 || (string)$request->input('confirmacion') !== 'CREAR_CURSO') {
            Response::abort(422, 'Confirmación inválida.');
        }
        try {
            $db = (new Database(new Config($_ENV)))->connection();
            $client = new MoodleRestClient($_ENV);
            $preview = (new MoodleAcademicPreview($db, $client))->preview($periodId);
            $user = (array)Session::get('auth_user', []);
            $actor = isset($user['id']) ? (int)$user['id'] : null;
            $id = (new MoodleCourseSync($db, $client))->create($preview, $periodId, $offerId, $subjectId, $actor);
            // La creación del curso ya se confirmó: un fallo de plantilla no revierte el vínculo.
            try {
                $client->templateSections($id);
                $summary = \App\Integrations\Moodle\MoodleInstitutionalTemplate::applyActivities($client, $id);
                Session::set('moodle_link_notice', 'Curso Moodle #'.$id.' creado y vinculado; 13 secciones y '.$summary['created'].' actividades base creadas. '.count($summary['errors']).' incidencias.');
            } catch (Throwable $templateError) {
                Session::set('moodle_link_notice', 'Curso Moodle #'.$id.' creado y vinculado, pero la plantilla quedó pendiente: '.$templateError->getMessage());
            }
        } catch (Throwable $e) {
            Session::set('moodle_link_notice', 'No se completó la creación: '.$e->getMessage());
        }
        Response::redirect('/admin/tic/moodle?periodo='.$periodId);
    }

    /** Plantilla institucional: acción separada, nunca se ejecuta al crear/vincular un curso. */
    public function applyTemplate(Request $request): never
    {
        AccessService::require('tic.cuentas.aprobar');
        if (!Csrf::validate((string)$request->input('_csrf'))) Response::abort(419, 'CSRF inválido.');
        $periodId = (int)$request->input('periodo');
        $courseId = (int)$request->input('moodle_course_id');
        if ($periodId < 1 || $courseId < 1 || (string)$request->input('confirmacion') !== 'APLICAR_PLANTILLA') Response::abort(422, 'Confirmación inválida.');
        try {
            $db = (new Database(new Config($_ENV)))->connection();
            $this->assertLinkedCourse($db, $periodId, $courseId);
            $result = (new MoodleRestClient($_ENV))->templateSections($courseId);
            Session::set('moodle_link_notice', 'Plantilla aplicada al curso #'.$courseId.'. '.(int)($result['created'] ?? 0).' secciones creadas.');
        } catch (Throwable $e) {
            Session::set('moodle_link_notice', 'Plantilla no aplicada: '.$e->getMessage());
        }
        Response::redirect('/admin/tic/moodle?periodo='.$periodId);
    }

    /** Completa actividades institucionales en cursos ya vinculados y con 13 secciones. */
    public function completeTemplate(Request $request): never
    {
        AccessService::require('tic.cuentas.aprobar');
        if (!Csrf::validate((string)$request->input('_csrf'))) Response::abort(419, 'CSRF inválido.');
        $periodId = (int)$request->input('periodo');
        $courseId = (int)$request->input('moodle_course_id');
        if ($periodId < 1 || $courseId < 1 || (string)$request->input('confirmacion') !== 'COMPLETAR_ACTIVIDADES') Response::abort(422, 'Confirmación inválida.');
        try {
            $db = (new Database(new Config($_ENV)))->connection();
            $this->assertLinkedCourse($db, $periodId, $courseId);
            $client = new MoodleRestClient($_ENV);
            $summary = \App\Integrations\Moodle\MoodleInstitutionalTemplate::applyActivities($client, $courseId);
            $message = 'Curso #'.$courseId.': '.$summary['created'].' actividades creadas; '.$summary['existing'].' ya existentes; '.count($summary['errors']).' errores.';
            if ($summary['errors']) $message .= ' Detalle: '.implode(' | ', array_slice($summary['errors'], 0, 4));
            Session::set('moodle_link_notice', $message);
        } catch (Throwable $e) {
            Session::set('moodle_link_notice', 'No se completaron las actividades: '.$e->getMessage());
        }
        Response::redirect('/admin/tic/moodle?periodo='.$periodId);
    }

    public function addTemplateActivity(Request $request): never
    {
        AccessService::require('tic.cuentas.aprobar');
        if (!Csrf::validate((string)$request->input('_csrf'))) Response::abort(419, 'CSRF inválido.');
        $periodId = (int)$request->input('periodo');
        $courseId = (int)$request->input('moodle_course_id');
        $section = (int)$request->input('sectionnum');
        $type = trim((string)$request->input('type'));
        $name = trim((string)$request->input('name'));
        $url = trim((string)$request->input('url'));
        if ($periodId < 1 || $courseId < 1 || $section < 1 || $section > 13 ||
            !in_array($type, ['forum','assign','quiz','url'], true) ||
            mb_strlen($name) < 3 || mb_strlen($name) > 255 ||
            (string)$request->input('confirmacion') !== 'CREAR_ACTIVIDAD') Response::abort(422, 'Datos de actividad inválidos.');
        if ($type === 'url' && (!filter_var($url, FILTER_VALIDATE_URL) || !in_array(strtolower((string)parse_url($url, PHP_URL_SCHEME)), ['https','http'], true))) Response::abort(422, 'URL inválida.');
        try {
            $db = (new Database(new Config($_ENV)))->connection();
            $this->assertLinkedCourse($db, $periodId, $courseId);
            $result = (new MoodleRestClient($_ENV))->templateActivity($courseId, $section, $type, $name, $url);
            Session::set('moodle_link_notice', 'Recurso/actividad creado en Moodle: '. $name.' (módulo #'.(int)($result['cmid'] ?? 0).').');
        } catch (Throwable $e) {
            Session::set('moodle_link_notice', 'No se creó la actividad: '.$e->getMessage());
        }
        Response::redirect('/admin/tic/moodle?periodo='.$periodId);
    }

    /** Sincronización individual de grupos: revalida el plan en servidor antes de escribir. */
    public function syncGroup(Request $request): never
    {
        AccessService::require('tic.cuentas.aprobar');
        if (!Csrf::validate((string)$request->input('_csrf'))) Response::abort(419, 'CSRF inválido.');
        if (!filter_var($_ENV['MOODLE_SYNC_ENABLED'] ?? false, FILTER_VALIDATE_BOOL)) Response::abort(403, 'Sincronización Moodle deshabilitada.');
        $periodId = (int)$request->input('periodo');
        $courseId = (int)$request->input('moodle_course_id');
        $sectionId = (int)$request->input('seccion_id');
        if ($periodId < 1 || $courseId < 1 || $sectionId < 1 || (string)$request->input('confirmacion') !== 'SINCRONIZAR_GRUPO') {
            Response::abort(422, 'Confirmación de grupo inválida.');
        }
        try {
            $db = (new Database(new Config($_ENV)))->connection();
            $this->assertLinkedCourse($db, $periodId, $courseId);
            $client = new MoodleRestClient($_ENV);
            $preview = (new MoodleAcademicPreview($db, $client))->preview($periodId);
            $selected = null;
            foreach ($preview['rows'] as $row) {
                if (!$row['saved_mapping'] || (int)$row['saved_mapping']['moodle_course_id'] !== $courseId) continue;
                foreach ($row['group_plan'] as $group) {
                    if ((int)$group['section_id'] === $sectionId) {
                        if ($selected !== null) throw new \RuntimeException('Sección ambigua entre asignaturas.');
                        $selected = $group;
                    }
                }
            }
            if (!$selected || $selected['needs_review'] || !in_array($selected['comparison_status'], ['faltante','encontrado'], true)) {
                throw new \RuntimeException('La sección requiere revisión o el grupo no se pudo verificar.');
            }
            // Reconsulta en vivo para evitar crear duplicados si cambió Moodle desde la vista previa.
            $name = (string)$selected['group_name'];
            $normalized = static fn(string $s): string => mb_strtolower(trim(preg_replace('/\s+/u', ' ', $s)), 'UTF-8');
            $matches = [];
            foreach ($client->courseGroups($courseId) as $group) {
                if ($normalized((string)($group['name'] ?? '')) === $normalized($name)) $matches[] = $group;
            }
            if (count($matches) > 1) throw new \RuntimeException('Hay varios grupos con ese nombre; requiere revisión manual.');
            $created = false;
            if (count($matches) === 1) {
                $groupId = (int)$matches[0]['id'];
            } else {
                $groupId = (int)$client->createGroup($courseId, $name)['id'];
                $created = true;
            }
            // Guardar el vínculo por ID, sin matricular personas ni modificar el grupo remoto.
            $stmt = $db->prepare('SELECT moodle_course_id,moodle_group_id FROM orion_moodle_vinculos_grupo WHERE seccion_id=?');
            $stmt->execute([$sectionId]);
            $prior = $stmt->fetch(\PDO::FETCH_ASSOC);
            if ($prior && ((int)$prior['moodle_course_id'] !== $courseId || (int)$prior['moodle_group_id'] !== $groupId)) {
                throw new \RuntimeException('La sección ya está vinculada a otro grupo; no se reemplazó.');
            }
            if (!$prior) {
                $stmt = $db->prepare('INSERT INTO orion_moodle_vinculos_grupo (seccion_id,moodle_course_id,moodle_group_id,nombre_grupo) VALUES (?,?,?,?)');
                $stmt->execute([$sectionId,$courseId,$groupId,$name]);
            }
            Session::set('moodle_link_notice', 'Grupo '.($created ? 'creado y vinculado' : 'existente vinculado').': '.$name.' (Moodle #'.$groupId.', curso #'.$courseId.').');
        } catch (Throwable $e) {
            Session::set('moodle_link_notice', 'No se sincronizó el grupo: '.$e->getMessage().' Si Moodle creó el grupo, vuelve a consultar antes de reintentar.');
        }
        Response::redirect('/admin/tic/moodle?periodo='.$periodId);
    }

    private function assertLinkedCourse(\PDO $db, int $periodId, int $courseId): void
    {
        $stmt = $db->prepare('SELECT 1 FROM orion_moodle_vinculos_asignatura WHERE periodo_academico_id=? AND moodle_course_id=? LIMIT 1');
        $stmt->execute([$periodId, $courseId]);
        if (!$stmt->fetchColumn()) throw new \RuntimeException('El curso no está vinculado a ese período en Orion.');
    }

    public function index(Request $request): void
    {
        AccessService::require('tic.cuentas.ver');
        $site = null; $error = null; $periods = []; $preview = null;
        $enabled = filter_var($_ENV['MOODLE_ENABLED'] ?? false, FILTER_VALIDATE_BOOL);
        if ($enabled) {
            try {
                $client = new MoodleRestClient($_ENV);
                $site = $client->siteInfo();
                $db = (new Database(new Config($_ENV)))->connection();
                $academic = new MoodleAcademicPreview($db, $client);
                $periods = $academic->periods();
                $periodId = filter_input(INPUT_GET, 'periodo', FILTER_VALIDATE_INT);
                if ($periodId && $periodId > 0) {
                    $preview = $academic->preview($periodId);
                    // Conciliación local de matrículas aprobadas, sin escrituras REST.
                    $sectionIds = [];
                    foreach ($preview['rows'] as $row) {
                        foreach ($row['group_plan'] as $group) $sectionIds[] = (int)$group['section_id'];
                    }
                    $enrollmentCounts = (new MoodleEnrollmentPreview($db))->forSections($sectionIds);
                    foreach ($preview['rows'] as &$row) {
                        foreach ($row['group_plan'] as &$group) {
                            $group['enrollment_preview'] = $enrollmentCounts[(int)$group['section_id']]
                                ?? ['eligible'=>0, 'excluded'=>0, 'total'=>0, 'reasons'=>[]];
                        }
                        unset($group);
                    }
                    unset($row);
                }
            } catch (Throwable $e) {
                $error = $e->getMessage();
            }
        }
        $linkNotice = Session::get('moodle_link_notice');
        Session::set('moodle_link_notice', null);
        View::render('admin/tic/moodle', [
            'title' => 'TIC · Integración Moodle', 'enabled' => $enabled,
            'site' => $site, 'error' => $error, 'periods' => $periods, 'preview' => $preview,
            'linkNotice' => $linkNotice, 'syncEnabled' => filter_var($_ENV['MOODLE_SYNC_ENABLED'] ?? false, FILTER_VALIDATE_BOOL) && AccessService::can('tic.cuentas.aprobar'),
        ]);
    }
}
