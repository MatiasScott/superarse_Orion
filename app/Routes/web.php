<?php
declare(strict_types=1);

use App\Controllers\{DashboardController,HealthController,HomeController,ProfileController};
use App\Controllers\Auth\{DevAuthController,LoginController};

$router->get('/',[HomeController::class,'index']);
$router->get('/login',[LoginController::class,'show']);
$router->get('/health',[HealthController::class,'index']);

$router->get('/dev/login',[DevAuthController::class,'form']);
$router->post('/dev/login',[DevAuthController::class,'login']);
$router->post('/dev/bootstrap',[DevAuthController::class,'bootstrap']);
$router->post('/logout',[DevAuthController::class,'logout']);

$router->get('/perfil',[ProfileController::class,'index']);
$router->post('/perfil',[ProfileController::class,'select']);
$router->get('/dashboard',[DashboardController::class,'index']);
