<?php
use App\Core\{Csrf,Session};
use App\Services\AccessService;
$u=rtrim($_ENV['APP_URL']??'','/');
$user=Session::get('auth_user');$profile=Session::get('active_profile');
?><!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title><?=htmlspecialchars($title??'Orion')?> | Superarse</title><link rel="stylesheet" href="<?=$u?>/assets/css/orion.css"></head>
<body><div class="shell">
<aside><div class="brand"><b>O</b><span><strong>Orion</strong><small>Superarse</small></span></div>
<nav>
<?php if(($profile['codigo']??'')==='ESTUDIANTE'): ?><div class="nav-label">MI INFORMACIÓN</div><a href="<?=$u?>/estudiante/financiero">Mi estado financiero</a><?php endif;?>
<a href="<?=$u?>/dashboard">⌂ Dashboard</a>
<?php if(AccessService::can('admin.usuarios.ver')||AccessService::can('admin.roles.ver')||AccessService::can('admin.permisos.ver')): ?>
<div class="nav-label">ADMINISTRACIÓN</div>
<?php if(AccessService::can('admin.usuarios.ver')):?><a href="<?=$u?>/admin/usuarios">Usuarios</a><?php endif;?>
<?php if(AccessService::can('admin.roles.ver')):?><a href="<?=$u?>/admin/roles">Roles</a><?php endif;?>
<?php if(AccessService::can('admin.permisos.ver')):?><a href="<?=$u?>/admin/permisos">Permisos</a><?php endif;?>
<?php endif;?>
<?php if(AccessService::can('tthh.personal.ver')): ?>
<div class="nav-label">GESTIÓN INSTITUCIONAL</div>
<a href="<?=$u?>/admin/tthh">Talento Humano</a>
<?php endif;?>
<?php if(AccessService::can('tic.cuentas.ver')): ?>
<div class="nav-label">TIC</div>
<a href="<?=$u?>/admin/tic">Cuentas institucionales</a>
<?php endif;?>
<?php if(AccessService::can('admisiones.solicitudes.ver')||AccessService::can('estudiantes.ver')): ?>
<div class="nav-label">ADMISIONES Y ESTUDIANTES</div>
<?php if(AccessService::can('admisiones.solicitudes.ver')):?><a href="<?=$u?>/admin/admisiones">Admisiones</a><?php endif;?>
<?php if(AccessService::can('estudiantes.ver')):?><a href="<?=$u?>/admin/estudiantes">Estudiantes</a><?php endif;?>
<?php endif;?>
<?php if(AccessService::can('academico.catalogos.ver')||AccessService::can('academico.estructura.ver')||AccessService::can('academico.oferta.ver')||AccessService::can('academico.matriculas.ver')): ?>
<div class="nav-label">ACADÉMICO</div>
<?php if(AccessService::can('academico.catalogos.ver')):?><a href="<?=$u?>/admin/academico/catalogos">Catálogos académicos</a><?php endif;?>
<?php if(AccessService::can('academico.estructura.ver')):?><a href="<?=$u?>/admin/academico/estructura">Estructura académica</a><?php endif;?>
<?php if(AccessService::can('academico.oferta.ver')):?><a href="<?=$u?>/admin/academico/oferta">Períodos y oferta</a><?php endif;?>
<?php if(AccessService::can('academico.matriculas.ver')):?><a href="<?=$u?>/admin/academico/matriculas">Matrículas y renovación</a><?php endif;?>
<?php endif;?>
<?php if(AccessService::can('financiero.ver')): ?><div class="nav-label">FINANCIERO</div><a href="<?=$u?>/admin/financiero">Órdenes y pagos</a><?php else: ?><div class="nav-label">PRÓXIMOS MÓDULOS</div><a class="muted-link">Financiero</a><?php endif;?>
</nav></aside>
<main><header><div><strong>Instituto Superior Tecnológico Superarse</strong><small class="header-profile"><?=htmlspecialchars($profile['nombre']??'')?></small></div>
<div class="user-menu"><span><?=htmlspecialchars($user['nombre']??'Usuario Orion')?></span>
<?php if($user):?><a href="<?=$u?>/perfil">Cambiar perfil</a><form method="post" action="<?=$u?>/logout"><input type="hidden" name="_csrf" value="<?=htmlspecialchars(Csrf::token())?>"><button class="link-button">Salir</button></form><?php endif;?></div></header>
<section><?=$content?></section></main></div></body></html>
