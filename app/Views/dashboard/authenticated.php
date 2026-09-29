<?php use App\Core\Csrf; $u=rtrim($_ENV['APP_URL']??'','/'); ?>
<div class="hero"><div><small>ORION · <?=htmlspecialchars($profile['codigo'])?></small><h1>Hola, <?=htmlspecialchars($user['nombre'])?></h1><p>Sesión autenticada contra la base real de Orion.</p></div></div>
<div class="cards">
 <article><span>Perfil activo</span><b><?=htmlspecialchars($profile['nombre'])?></b><small><?=htmlspecialchars($profile['ruta_inicio'])?></small></article>
 <article><span>Roles</span><b><?=count($roles)?></b><small><?=htmlspecialchars(implode(', ',array_column($roles,'nombre')))?></small></article>
 <article><span>Permisos</span><b><?=in_array('*',$permissions,true)?'GLOBAL':count($permissions)?></b><small><?=in_array('*',$permissions,true)?'Super Administrador':'RBAC activo'?></small></article>
 <article><span>Usuario</span><b>#<?=(int)$user['id']?></b><small><?=htmlspecialchars($user['identificacion'])?></small></article>
</div>
<div style="margin-top:24px;display:flex;gap:12px">
 <a class="btn" href="<?=$u?>/perfil">Cambiar perfil</a>
 <form method="post" action="<?=$u?>/logout"><input type="hidden" name="_csrf" value="<?=htmlspecialchars(Csrf::token())?>"><button class="btn" type="submit">Cerrar sesión</button></form>
</div>
