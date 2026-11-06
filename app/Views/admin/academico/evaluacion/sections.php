<?php
$u=rtrim($_ENV['APP_URL']??'','/');
$h=static fn($v):string=>htmlspecialchars((string)$v,ENT_QUOTES,'UTF-8');
?>
<div class="page-head"><div><span class="eyebrow">ACADÉMICO · EVALUACIÓN</span><h1>Esquemas por sección</h1><p>Asigna una versión publicada y vigente. Cada sección conserva su versión de forma permanente.</p></div><a href="<?=$h($u)?>/admin/academico/evaluacion">Volver a esquemas</a></div>
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
<?php elseif(!$assigned): ?><small><?=$started?'Sección ya iniciada':((int)$section['activo']!==1?'Sección inactiva':'No hay versiones publicadas vigentes')?></small><?php else: ?>—<?php endif; ?></td></tr>
<?php endforeach; if(!$sections): ?><tr><td colspan="5">No hay secciones registradas.</td></tr><?php endif; ?>
</tbody></table></div><p><small>Se muestran hasta 300 secciones, ordenadas por período y asignatura.</small></p></section>
