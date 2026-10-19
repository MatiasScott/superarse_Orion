<?php
declare(strict_types=1);
namespace App\Controllers\Admin;

use App\Core\Request;
use App\Core\View;
use App\Core\Config;
use App\Core\Database;
use App\Integrations\Moodle\MoodleRestClient;
use App\Integrations\Moodle\MoodleAcademicPreview;
use App\Services\AccessService;
use Throwable;

final class MoodleIntegrationController
{
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
        View::render('admin/tic/moodle', [
            'title' => 'TIC · Integración Moodle', 'enabled' => $enabled,
            'site' => $site, 'error' => $error, 'periods' => $periods, 'preview' => $preview,
        ]);
    }
}
