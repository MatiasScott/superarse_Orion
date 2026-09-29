<?php
declare(strict_types=1);

use App\Controllers\HealthController;
use App\Controllers\HomeController;
use App\Controllers\Auth\LoginController;

/** @var \App\Core\Router $router */

$router->get('/', [HomeController::class, 'index']);
$router->get('/login', [LoginController::class, 'show']);
$router->get('/health', [HealthController::class, 'index']);
