<?php use App\Core\Csrf;$u=rtrim($_ENV['APP_URL']??'','/'); ?>
<div class="page-head"><div><small>TALENTO HUMANO</small><h1>Registrar personal</h1><p>El alta crea la ficha laboral y, si corresponde, deja la solicitud de cuenta pendiente para TIC.</p></div><a href="<?=$u?>/admin/tthh">← Volver</a></div>
<form class="form-card" method="post" action="<?=$u?>/admin/tthh/save"><input type="hidden" name="_csrf" value="<?=htmlspecialchars(Csrf::token())?>">
<h3>1. Datos personales</h3><div class="form-grid">
<label>Tipo de identificación<select name="tipo_identificacion_id" required><option value="">Seleccione...</option><?php foreach($types as $x):?><option value="<?=$x['id']?>"><?=htmlspecialchars($x['nombre'])?></option><?php endforeach;?></select></label>
<label>Número de identificación<input name="numero_identificacion" required maxlength="30"></label>
<label>Primer nombre<input name="primer_nombre" required maxlength="80"></label><label>Segundo nombre<input name="segundo_nombre" maxlength="80"></label>
<label>Primer apellido<input name="primer_apellido" required maxlength="80"></label><label>Segundo apellido<input name="segundo_apellido" maxlength="80"></label></div>
<h3>2. Clasificación institucional</h3><div class="check-grid"><?php foreach($personnelTypes as $x):?><label class="check"><input type="checkbox" name="tipos_personal[]" value="<?=$x['id']?>"><span><strong><?=htmlspecialchars($x['nombre'])?></strong><small><?=htmlspecialchars($x['descripcion']??'')?></small></span></label><?php endforeach;?></div>
<h3>3. Relación laboral</h3><div class="form-grid">
<label>Fecha de inicio<input type="date" name="fecha_inicio" required value="<?=date('Y-m-d')?>"></label><label>Fecha fin prevista<input type="date" name="fecha_fin_prevista"></label>
<label>Estado<select name="estado_relacion_id" required><option value="">Seleccione...</option><?php foreach($states as $x):?><option value="<?=$x['id']?>" <?=$x['codigo']==='ACTIVA'?'selected':''?>><?=htmlspecialchars($x['nombre'])?></option><?php endforeach;?></select></label>
<label>Tipo de contrato<select name="tipo_contrato_id"><option value="0">No especificado</option><?php foreach($contracts as $x):?><option value="<?=$x['id']?>"><?=htmlspecialchars($x['nombre'])?></option><?php endforeach;?></select></label>
<label>Jornada<select name="tipo_jornada_id"><option value="0">No especificada</option><?php foreach($workdays as $x):?><option value="<?=$x['id']?>"><?=htmlspecialchars($x['nombre'])?><?=isset($x['horas_semanales'])&&$x['horas_semanales']!==null?' · '.$x['horas_semanales'].' h':''?></option><?php endforeach;?></select></label>
<label>Número de contrato<input name="numero_contrato" maxlength="100"></label></div>
<h3>4. Asignación principal</h3><div class="form-grid">
<label>Cargo<select name="cargo_id" required><option value="">Seleccione...</option><?php foreach($positions as $x):?><option value="<?=$x['id']?>"><?=htmlspecialchars($x['nombre'])?></option><?php endforeach;?></select></label>
<label>Unidad / Área<select name="unidad_organizacional_id"><option value="0">No especificada</option><?php foreach($units as $x):?><option value="<?=$x['id']?>"><?=htmlspecialchars($x['nombre'])?></option><?php endforeach;?></select></label>
<label>Sede<select name="sede_id"><option value="0">No especificada</option><?php foreach($campuses as $x):?><option value="<?=$x['id']?>"><?=htmlspecialchars($x['nombre'])?></option><?php endforeach;?></select></label></div>
<h3>5. Cuenta institucional</h3><label class="check wide"><input type="checkbox" name="solicitar_cuenta" value="1" checked><span><strong>Enviar solicitud de cuenta a TIC</strong><small>Orion creará la solicitud pendiente. En este paso no se crea todavía la cuenta Microsoft.</small></span></label>
<label class="block-label">Observación<textarea name="observacion" rows="3" maxlength="3000"></textarea></label>
<div class="actions"><a href="<?=$u?>/admin/tthh">Cancelar</a><button class="btn" type="submit">Registrar personal</button></div></form>
