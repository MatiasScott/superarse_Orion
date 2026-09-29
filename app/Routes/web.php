<?php

declare(strict_types=1);

use App\Controllers\{DashboardController, HealthController, HomeController, ProfileController};
use App\Controllers\Auth\{DevAuthController, LoginController};
use App\Controllers\Admin\IdentityAdminController;
use App\Controllers\Auth\MicrosoftAuthController;

$router->get(
    '/',
    [HomeController::class, 'index']
);
$router->get(
    '/login',
    [LoginController::class, 'show']
);
$router->get(
    '/health',
    [HealthController::class, 'index']
);
$router->get(
    '/dev/login',
    [DevAuthController::class, 'form']
);
$router->post(
    '/dev/login',
    [DevAuthController::class, 'login']
);
$router->post(
    '/dev/bootstrap',
    [DevAuthController::class, 'bootstrap']
);
$router->post(
    '/logout',
    [DevAuthController::class, 'logout']
);
$router->get(
    '/perfil',
    [ProfileController::class, 'index']
);
$router->post(
    '/perfil',
    [ProfileController::class, 'select']
);
$router->get(
    '/dashboard',
    [DashboardController::class, 'index']
);

$router->get(
    '/admin/usuarios',
    [IdentityAdminController::class, 'users']
);
$router->get(
    '/admin/usuarios/form',
    [IdentityAdminController::class, 'userForm']
);
$router->post(
    '/admin/usuarios/save',
    [IdentityAdminController::class, 'userSave']
);
$router->get(
    '/admin/roles',
    [IdentityAdminController::class, 'roles']
);
$router->get(
    '/admin/roles/form',
    [IdentityAdminController::class, 'roleForm']
);
$router->post(
    '/admin/roles/save',
    [IdentityAdminController::class, 'roleSave']
);
$router->get(
    '/admin/permisos',
    [IdentityAdminController::class, 'permissions']
);
$router->get(
    '/admin/roles/permisos',
    [IdentityAdminController::class, 'rolePermissions']
);
$router->post(
    '/admin/roles/permisos/save',
    [IdentityAdminController::class, 'rolePermissionsSave']
);
$router->get(
    '/auth/microsoft',
    [MicrosoftAuthController::class, 'redirect']
);
$router->get(
    '/auth/microsoft/callback',
    [MicrosoftAuthController::class, 'callback']
);
