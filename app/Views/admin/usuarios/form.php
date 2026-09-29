<?php use App\Core\Csrf;$u=rtrim($_ENV['APP_URL']??'','/');$edit=!empty($user);?>
<div class="page-head"><div><small>ADMINISTRACIÓN · USUARIOS</small><h1><?=$edit?'Editar usuario':'Nuevo usuario'?></h1></div><a href="<?=$u?>/admin/usuarios">Volver</a></div>
<form class="form-card" method="post" action="<?=$u?>/admin/usuarios/save"><input type="hidden" name="_csrf" value="<?=htmlspecialchars(Csrf::token())?>"><input type="hidden" name="id" value="<?=$edit?(int)$user['id']:0?>">
<div class="form-grid">
<label>Tipo de identificación<select name="tipo_identificacion_id" required><?php foreach($types as $x):?><option value="<?=$x['id']?>" <?=($edit&&(int)$user['tipo_identificacion_id']==(int)$x['id'])?'selected':''?>><?=htmlspecialchars($x['nombre'])?></option><?php endforeach;?></select></label>
<label>Identificación<input name="numero_identificacion" required value="<?=htmlspecialchars($user['numero_identificacion']??'')?>"></label>
<label>Primer nombre<input name="primer_nombre" required value="<?=htmlspecialchars($user['primer_nombre']??'')?>"></label>
<label>Segundo nombre<input name="segundo_nombre" value="<?=htmlspecialchars($user['segundo_nombre']??'')?>"></label>
<label>Primer apellido<input name="primer_apellido" required value="<?=htmlspecialchars($user['primer_apellido']??'')?>"></label>
<label>Segundo apellido<input name="segundo_apellido" value="<?=htmlspecialchars($user['segundo_apellido']??'')?>"></label>
<label>Estado<select name="estado_usuario_id"><?php foreach($states as $x):?><option value="<?=$x['id']?>" <?=($edit&&(int)$user['estado_usuario_id']==(int)$x['id'])?'selected':''?>><?=htmlspecialchars($x['nombre'])?></option><?php endforeach;?></select></label>
<label class="check"><input type="checkbox" name="activo" value="1" <?=!$edit||$user['activo']?'checked':''?>> Usuario activo</label>
</div>
<h3>Perfiles</h3><div class="check-grid"><?php foreach($profiles as $x):?><label class="check"><input type="checkbox" name="perfiles[]" value="<?=$x['id']?>" <?=in_array((int)$x['id'],$selectedProfiles,true)?'checked':''?>> <span><b><?=htmlspecialchars($x['nombre'])?></b><small><?=htmlspecialchars($x['descripcion']??'')?></small></span></label><?php endforeach;?></div>
<h3>Roles</h3><div class="check-grid"><?php foreach($roles as $x):?><label class="check"><input type="checkbox" name="roles[]" value="<?=$x['id']?>" <?=in_array((int)$x['id'],$selectedRoles,true)?'checked':''?>> <span><b><?=htmlspecialchars($x['nombre'])?></b><small><?=htmlspecialchars($x['perfil_nombre']??'Global')?></small></span></label><?php endforeach;?></div>
<div class="actions"><a href="<?=$u?>/admin/usuarios">Cancelar</a><button class="btn" type="submit">Guardar usuario</button></div></form>
