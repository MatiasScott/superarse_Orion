<?php
$error=\App\Core\Session::get('evaluacion_error');\App\Core\Session::set('evaluacion_error',null);
$notice=\App\Core\Session::get('evaluacion_notice');\App\Core\Session::set('evaluacion_notice',null);
$u=rtrim($_ENV['APP_URL']??'','/');
$h=static fn($v):string=>htmlspecialchars((string)$v,ENT_QUOTES,'UTF-8');
?>
<div class="page-head"><div><span class="eyebrow">ACADÉMICO · EVALUACIÓN</span><h1>Esquemas por sección</h1><p>Asigna una versión publicada y vigente. Cada sección conserva su versión de forma permanente.</p></div><a href="<?=$h($u)?>/admin/academico/evaluacion">Volver a esquemas</a></div>
<?php if($error || $notice): ?><dialog id="eval-feedback" style="max-width:540px;border:1px solid #ccd5e2;border-radius:12px;padding:24px"><h3><?=$error?'No se pudo reasignar':'Reasignación completada'?></h3><p><?=$h($error?:$notice)?></p><form method="dialog"><button class="btn btn-primary">Entendido</button></form></dialog><script>document.getElementById('eval-feedback').showModal();</script><?php endif; ?>
<section class="card"><p>Solo se permiten asignaciones iniciales a secciones activas que aún no han iniciado. La asignación queda bloqueada; no modifica notas ni sincroniza Moodle.</p>
<div class="table-scroll"><table><thead><tr><th>Período</th><th>Sección / asignatura</th><th>Estado</th><th>Esquema asignado</th><th>Acción</th></tr></thead><tbody>
<?php foreach($sections as $section):
$assigned=$section['asignacion_id']!==null;
$started=$section['fecha_apertura']!==null && strtotime((string)$section['fecha_apertura'])<=time();
$canAssign=!$assigned && (int)$section['activo']===1 && !$started && count($versions)>0;
?>
<tr><td><?=$h($section['periodo'])?></td><td><strong><?=$h($section['codigo'])?></strong> · <?=$h($section['nombre'])?><br><small><?=$h($section['asignatura'])?></small></td><td><?=$h($section['estado_seccion'])?></td>
<td><?php if($assigned): ?><strong><?=$h($section['esquema_nombre'])?> · v<?=$h($section['numero_version'])?></strong><br><small>Asignado: <?=$h($section['fecha_asignacion'])?> · Bloqueado</small><?php else: ?>Sin asignar<?php endif; ?></td>
<td><?php if($canAssign): ?><form method="post" action="<?=$h($u)?>/admin/academico/evaluacion/secciones/asignar" onsubmit="return confirm('¿Asignar y bloquear esta versión para la sección? No se podrá cambiar desde esta pantalla.');">
<input type="hidden" name="_csrf" value="<?=$h(\App\Core\Csrf::token())?>"><input type="hidden" name="seccion_id" value="<?=(int)$section['id']?>">
<select name="esquema_version_id" required aria-label="Versión de evaluación">
<option value="">Seleccionar versión</option><?php foreach($versions as $v): ?><option value="<?=(int)$v['id']?>"><?=$h($v['esquema_nombre'])?> · v<?=$h($v['numero_version'])?></option><?php endforeach; ?>
</select><button type="submit" class="btn btn-primary">Asignar y bloquear</button></form>
<?php elseif(!$assigned): ?><small><?=$started?'Sección ya iniciada':((int)$section['activo']!==1?'Sección inactiva':'No hay versiones publicadas vigentes')?></small><?php elseif(!empty($canReassign) && (int)$section['activo']===1 && count($versions)>0): ?>
<button type="button" class="btn" onclick="document.getElementById('reassign-<?=(int)$section['id']?>').showModal()">Reasignación TICs</button>
<dialog id="reassign-<?=(int)$section['id']?>" style="max-width:560px;border:1px solid #ccd5e2;border-radius:12px;padding:24px">
<h3>Reasignar <?=$h($section['codigo'])?></h3><p>Versión actual: <?=$h($section['esquema_nombre'])?> · v<?=$h($section['numero_version'])?>. Solo TICs; se bloqueará si existen recursos, vínculos o notas.</p>
<form method="post" action="<?=$h($u)?>/admin/academico/evaluacion/secciones/reasignar">
<input type="hidden" name="_csrf" value="<?=$h(\App\Core\Csrf::token())?>"><input type="hidden" name="seccion_id" value="<?=(int)$section['id']?>">
<label>Nueva versión vigente <select name="esquema_version_id" required><option value="">Seleccionar</option><?php foreach($versions as $v):if((int)$v['id']===(int)$section['esquema_version_id'])continue;?><option value="<?=(int)$v['id']?>"><?=$h($v['esquema_nombre'])?> · v<?=$h($v['numero_version'])?></option><?php endforeach;?></select></label>
<label>Motivo de auditoría (mínimo 15 caracteres)<textarea name="motivo" minlength="15" maxlength="1000" required rows="4" style="display:block;width:100%"></textarea></label>
<p><button class="btn btn-primary" type="submit">Confirmar reasignación excepcional</button> <button type="button" class="btn" onclick="this.closest('dialog').close()">Cancelar</button></p></form></dialog>
<?php else: ?>—<?php endif; ?></td></tr>
<?php endforeach; if(!$sections): ?><tr><td colspan="5">No hay secciones registradas.</td></tr><?php endif; ?>
</tbody></table></div><p><small>Se muestran hasta 300 secciones, ordenadas por período y asignatura.</small></p></section>
