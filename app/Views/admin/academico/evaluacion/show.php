<?php
$error=\App\Core\Session::get('evaluacion_error');\App\Core\Session::set('evaluacion_error',null);
$notice=\App\Core\Session::get('evaluacion_notice');\App\Core\Session::set('evaluacion_notice',null);
$u=rtrim($_ENV['APP_URL']??'','/');
$h=static fn($v):string=>htmlspecialchars((string)$v,ENT_QUOTES,'UTF-8');
$active=array_values(array_filter($partials,static fn($p)=>(int)$p['activo']===1));
$total=array_sum(array_map(static fn($p)=>(float)$p['ponderacion_nota_final'],$active));
$valid=count($active)>0 && abs($total-100)<0.001;
foreach($active as $p){if((int)$p['parametros']===0 || abs((float)$p['total_parametros']-100)>0.001){$valid=false;}}
?>
<div class="page-head"><div><span class="eyebrow">ACADÉMICO · EVALUACIÓN</span><h1><?=$h($version['esquema_nombre'])?> · versión <?=$h($version['numero_version'])?></h1><p><?=$h($version['estado_nombre'])?> · Vigencia desde <?=$h($version['vigente_desde'])?>. Diagnóstico de solo lectura.</p></div><a href="<?=$h($u)?>/admin/academico/evaluacion">Volver a esquemas</a></div>
<?php if($error || $notice): ?><dialog id="eval-feedback" style="max-width:540px;border:1px solid #ccd5e2;border-radius:12px;padding:24px"><h3><?=$error?'No se pudo completar la operación':'Operación completada'?></h3><p><?=$h($error?:$notice)?></p><form method="dialog"><button class="btn btn-primary">Entendido</button></form></dialog><script>document.getElementById('eval-feedback').showModal();</script><?php endif; ?>
<section class="card"><div class="section-head"><h2>Validación de ponderaciones</h2></div><p><strong><?=$valid?'Ponderaciones completas':'Configuración pendiente de revisión'?></strong>. La suma de parciales activos debe ser 100 % y la de parámetros activos de cada parcial también debe ser 100 %.</p><p>Este diagnóstico no publica versiones ni autoriza cambios en versiones publicadas.</p></section>
<?php foreach($partials as $p): $params=array_values(array_filter($parameters,static fn($x)=>(int)$x['parcial_id']===(int)$p['id'])); $ok=count($params)>0 && abs((float)$p['total_parametros']-100)<0.001; ?>
<section class="card"><div class="section-head"><div><span class="eyebrow">PARCIAL <?=$h($p['codigo'])?></span><h2><?=$h($p['nombre'])?></h2></div></div><p>Peso en nota final: <strong><?=$h($p['ponderacion_nota_final'])?> %</strong> · Parámetros activos: <?=$h($p['total_parametros'])?> % · <?=$ok?'Correcto':'Revisar'?> · <?=$p['activo']?'Activo':'Inactivo'?></p><div class="table-scroll"><table><thead><tr><th>Parámetro</th><th>Código</th><th>Ponderación</th><th>Estado</th></tr></thead><tbody><?php foreach($params as $param):?><tr><td><?=$h($param['nombre'])?></td><td><?=$h($param['codigo'])?></td><td><?=$h($param['ponderacion_parcial'])?> %</td><td><?=$param['activo']?'Activo':'Inactivo'?></td></tr><?php endforeach;if(!$params):?><tr><td colspan="4">No existen parámetros para este parcial.</td></tr><?php endif;?></tbody></table></div></section>
<?php endforeach;if(!$partials):?><section class="card"><p>Esta versión todavía no tiene parciales configurados.</p></section><?php endif;?>

<?php if ((int)$version['es_publicado']===0 && $version['estado_codigo']==='BORRADOR'): ?>
<section class="card"><div class="section-head"><h2>Editar ponderaciones del borrador</h2></div>
<p>Las versiones publicadas no se pueden modificar. La publicación requerirá ponderaciones completas; aquí puedes guardar un borrador incompleto.</p>
<form method="post" action="<?=$h($u)?>/admin/academico/evaluacion/ponderaciones/save">
<input type="hidden" name="_csrf" value="<?=$h(\App\Core\Csrf::token())?>"><input type="hidden" name="id" value="<?=(int)$version['id']?>">
<h3>Parciales</h3>
<?php foreach ($partials as $p): ?><label style="display:block;margin:12px 0"><?=$h($p['codigo'])?> · <?=$h($p['nombre'])?> <input type="number" min="0.01" max="100" step="0.01" required name="parciales[<?=(int)$p['id']?>]" value="<?=$h($p['ponderacion_nota_final'])?>"> %</label><?php endforeach; ?>
<h3>Parámetros</h3>
<?php foreach ($parameters as $pa): ?><label style="display:block;margin:12px 0"><?=$h($pa['codigo'])?> · <?=$h($pa['nombre'])?> <input type="number" min="0.01" max="100" step="0.01" required name="parametros[<?=(int)$pa['id']?>]" value="<?=$h($pa['ponderacion_parcial'])?>"> %</label><?php endforeach; ?>
<button type="submit" class="btn btn-primary">Guardar ponderaciones del borrador</button></form></section>
<?php endif; ?>

<?php if ($version['estado_codigo']==='BORRADOR'): ?>
<section class="card"><div class="section-head"><h2>Publicar versión de evaluación</h2></div>
<p>La publicación requiere P1 y P2 al 50 % cada uno, con parámetros activos que sumen 100 % por parcial. Se archivará la versión actualmente publicada del mismo esquema y se conservará su historial.</p>
<?php if ($valid && count($active)===2 && count(array_filter($active, static fn($p)=>in_array(strtoupper((string)$p['codigo']),['P1','P2'],true) && abs((float)$p['ponderacion_nota_final']-50)<0.001))===2): ?>
<?php if(!empty($publicationMinimum)): ?><p>Fecha mínima de vigencia para publicar: <strong><?=$h($publicationMinimum)?></strong>.</p><?php endif; ?>
<form method="post" action="<?=$h($u)?>/admin/academico/evaluacion/publicar/save" onsubmit="return confirm('¿Publicar esta versión? La versión anterior quedará histórica y no se podrá editar.');">
<input type="hidden" name="_csrf" value="<?=$h(\App\Core\Csrf::token())?>"><input type="hidden" name="id" value="<?=(int)$version['id']?>">
<button type="submit" class="btn btn-primary">Publicar versión</button></form>
<?php else: ?><p><strong>Publicación bloqueada:</strong> revisa los dos parciales y sus ponderaciones.</p><?php endif; ?>
</section>
<?php endif; ?>
