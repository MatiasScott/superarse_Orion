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
            'linkNotice' => $linkNotice,
        ]);
    }
}
