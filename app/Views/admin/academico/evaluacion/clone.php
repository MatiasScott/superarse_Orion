<?php
$u=rtrim($_ENV['APP_URL']??'','/');
$h=static fn($v):string=>htmlspecialchars((string)$v,ENT_QUOTES,'UTF-8');
?>
<div class="page-head"><div><span class="eyebrow">ACADÉMICO · EVALUACIÓN</span><h1>Crear borrador desde una versión</h1><p>La versión original y sus calificaciones permanecen intactas.</p></div><a href="<?=$h($u)?>/admin/academico/evaluacion">Volver</a></div>
<section class="card"><h2><?=$h($version['esquema_nombre'])?> · v<?=$h($version['numero_version'])?></h2>
<p>Se copiarán sus parciales y parámetros a una nueva versión BORRADOR, sin publicar ni sincronizar Moodle.</p>
<form method="post" action="<?=$h($u)?>/admin/academico/evaluacion/borrador/save">
<input type="hidden" name="_csrf" value="<?=$h(\App\Core\Csrf::token())?>"><input type="hidden" name="id" value="<?=(int)$version['id']?>">
<div class="form-grid"><label>Nombre de nueva versión<input type="text" name="nombre_version" maxlength="180" required value="Borrador de <?=$h($version['esquema_nombre'])?>"></label>
<label>Vigente desde<input type="date" name="vigente_desde" required value="<?=date('Y-m-d')?>"></label></div>
<button type="submit" class="btn btn-primary">Crear versión borrador</button>
</form></section>
