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
<a href="<?=$u?>/dashboard">⌂ Dashboard</a>
<?php if(AccessService::can('admin.usuarios.ver')||AccessService::can('admin.roles.ver')||AccessService::can('admin.permisos.ver')): ?>
<div class="nav-label">ADMINISTRACIÓN</div>
<?php if(AccessService::can('admin.usuarios.ver')):?><a href="<?=$u?>/admin/usuarios">Usuarios</a><?php endif;?>
<?php if(AccessService::can('admin.roles.ver')):?><a href="<?=$u?>/admin/roles">Roles</a><?php endif;?>
<?php if(AccessService::can('admin.permisos.ver')):?><a href="<?=$u?>/admin/permisos">Permisos</a><?php endif;?>
<?php endif;?>
<div class="nav-label">PRÓXIMOS MÓDULOS</div><a class="muted-link">Académico</a><a class="muted-link">Estudiantes</a><a class="muted-link">Financiero</a>
</nav></aside>
<main><header><div><strong>Instituto Superior Tecnológico Superarse</strong><small class="header-profile"><?=htmlspecialchars($profile['nombre']??'')?></small></div>
<div class="user-menu"><span><?=htmlspecialchars($user['nombre']??'Usuario Orion')?></span>
<?php if($user):?><a href="<?=$u?>/perfil">Cambiar perfil</a><form method="post" action="<?=$u?>/logout"><input type="hidden" name="_csrf" value="<?=htmlspecialchars(Csrf::token())?>"><button class="link-button">Salir</button></form><?php endif;?></div></header>
<section><?=$content?></section></main></div></body></html>
