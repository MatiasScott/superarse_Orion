<?php
$u=rtrim($_ENV['APP_URL']??'','/');
$h=static fn($v):string=>htmlspecialchars((string)$v,ENT_QUOTES,'UTF-8');
$active=array_values(array_filter($partials,static fn($p)=>(int)$p['activo']===1));
$total=array_sum(array_map(static fn($p)=>(float)$p['ponderacion_nota_final'],$active));
$valid=count($active)>0 && abs($total-100)<0.001;
foreach($active as $p){if((int)$p['parametros']===0 || abs((float)$p['total_parametros']-100)>0.001){$valid=false;}}
?>
<div class="page-head"><div><span class="eyebrow">ACADÉMICO · EVALUACIÓN</span><h1><?=$h($version['esquema_nombre'])?> · versión <?=$h($version['numero_version'])?></h1><p><?=$h($version['estado_nombre'])?> · Vigencia desde <?=$h($version['vigente_desde'])?>. Diagnóstico de solo lectura.</p></div><a href="<?=$h($u)?>/admin/academico/evaluacion">Volver a esquemas</a></div>
<section class="card"><div class="section-head"><h2>Validación de ponderaciones</h2></div><p><strong><?=$valid?'Ponderaciones completas':'Configuración pendiente de revisión'?></strong>. La suma de parciales activos debe ser 100 % y la de parámetros activos de cada parcial también debe ser 100 %.</p><p>Este diagnóstico no publica versiones ni autoriza cambios en versiones publicadas.</p></section>
<?php foreach($partials as $p): $params=array_values(array_filter($parameters,static fn($x)=>(int)$x['parcial_id']===(int)$p['id'])); $ok=count($params)>0 && abs((float)$p['total_parametros']-100)<0.001; ?>
<section class="card"><div class="section-head"><div><span class="eyebrow">PARCIAL <?=$h($p['codigo'])?></span><h2><?=$h($p['nombre'])?></h2></div></div><p>Peso en nota final: <strong><?=$h($p['ponderacion_nota_final'])?> %</strong> · Parámetros activos: <?=$h($p['total_parametros'])?> % · <?=$ok?'Correcto':'Revisar'?> · <?=$p['activo']?'Activo':'Inactivo'?></p><div class="table-scroll"><table><thead><tr><th>Parámetro</th><th>Código</th><th>Ponderación</th><th>Estado</th></tr></thead><tbody><?php foreach($params as $param):?><tr><td><?=$h($param['nombre'])?></td><td><?=$h($param['codigo'])?></td><td><?=$h($param['ponderacion_parcial'])?> %</td><td><?=$param['activo']?'Activo':'Inactivo'?></td></tr><?php endforeach;if(!$params):?><tr><td colspan="4">No existen parámetros para este parcial.</td></tr><?php endif;?></tbody></table></div></section>
<?php endforeach;if(!$partials):?><section class="card"><p>Esta versión todavía no tiene parciales configurados.</p></section><?php endif;?>
