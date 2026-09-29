<?php use App\Core\Csrf;$u=rtrim($_ENV['APP_URL']??'','/');$edit=!empty($role);?>
<div class="page-head"><div><small>ADMINISTRACIÓN · ROLES</small><h1><?=$edit?'Editar rol':'Nuevo rol'?></h1></div><a href="<?=$u?>/admin/roles">Volver</a></div>
<form class="form-card narrow" method="post" action="<?=$u?>/admin/roles/save"><input type="hidden" name="_csrf" value="<?=htmlspecialchars(Csrf::token())?>"><input type="hidden" name="id" value="<?=$edit?(int)$role['id']:0?>">
<label>Código<input name="codigo" required value="<?=htmlspecialchars($role['codigo']??'')?>" <?=$edit?'readonly':''?> placeholder="COORDINADOR_ACADEMICO"></label>
<label>Nombre<input name="nombre" required value="<?=htmlspecialchars($role['nombre']??'')?>"></label>
<label>Perfil<select name="perfil_id"><option value="0">Global / sin perfil</option><?php foreach($profiles as $p):?><option value="<?=$p['id']?>" <?=($edit&&(int)$role['perfil_id']==(int)$p['id'])?'selected':''?>><?=htmlspecialchars($p['nombre'])?></option><?php endforeach;?></select></label>
<label>Descripción<textarea name="descripcion" rows="4"><?=htmlspecialchars($role['descripcion']??'')?></textarea></label>
<?php if($edit):?><label class="check"><input type="checkbox" name="activo" value="1" <?=$role['activo']?'checked':''?>> Rol activo</label><?php endif;?>
<div class="actions"><a href="<?=$u?>/admin/roles">Cancelar</a><button class="btn">Guardar rol</button></div></form>
