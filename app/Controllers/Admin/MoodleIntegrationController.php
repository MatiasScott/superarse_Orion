<?php
declare(strict_types=1);
namespace App\Controllers\Admin;

use App\Core\Request;
use App\Core\View;
use App\Integrations\Moodle\MoodleRestClient;
use App\Services\AccessService;
use Throwable;

final class MoodleIntegrationController
{
    public function index(Request $request): void
    {
        AccessService::require('tic.cuentas.ver');
        $site = null;
        $error = null;
        $enabled = filter_var($_ENV['MOODLE_ENABLED'] ?? false, FILTER_VALIDATE_BOOL);
        if ($enabled) {
            try {
                $site = (new MoodleRestClient($_ENV))->siteInfo();
            } catch (Throwable $e) {
                $error = $e->getMessage();
            }
        }
        View::render('admin/tic/moodle', [
            'title' => 'TIC · Integración Moodle',
            'enabled' => $enabled,
            'site' => $site,
            'error' => $error,
        ]);
    }
}
