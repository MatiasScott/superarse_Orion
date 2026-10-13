<?php $u=rtrim($_ENV['APP_URL']??'','/');$fmt=static fn($v)=>$v===null||$v===''?'—':number_format((float)$v,2); ?>
<div class="page-head"><div><span class="eyebrow">HISTORIAL ACADÉMICO · <?=htmlspecialchars($student['codigo_estudiante'])?></span><h1><?=htmlspecialchars($student['nombre'])?></h1><p><?=htmlspecialchars($student['numero_identificacion'])?> · Expediente académico consolidado</p></div><div class="page-actions"><a class="btn secondary" href="<?=$u?>/admin/estudiantes/ver?id=<?=$student['id']?>">← Ficha estudiante</a><a class="btn secondary" href="<?=$u?>/admin/academico/trayectoria?id=<?=$student['id']?>">Trayectorias</a></div></div>
<?php if(!$history):?><section class="card"><div class="empty">Este estudiante todavía no tiene trayectorias académicas.</div></section><?php endif;?>
<div class="academic-history">
<?php foreach($history as $block):$t=$block['trajectory'];?>
<section class="history-trajectory card">
 <div class="history-trajectory-head"><div><span class="eyebrow">TRAYECTORIA #<?=$t['id']?></span><h2><?=htmlspecialchars($t['carrera'])?></h2><p><?=htmlspecialchars($t['malla_codigo'].' · '.$t['malla'])?></p></div><div class="history-meta"><span class="badge on"><?=htmlspecialchars($t['estado'])?></span><small><?=htmlspecialchars($t['sede']?:'Sin sede')?> · <?=htmlspecialchars($t['modalidad']?:'Sin modalidad')?></small><small>Inicio: <?=htmlspecialchars($t['fecha_inicio'])?></small></div></div>
 <?php if(!$block['periods']):?><div class="empty">Sin matrículas registradas en esta trayectoria.</div><?php endif;?>
 <?php foreach($block['periods'] as $period):?>
 <details class="history-period" open><summary><div><strong><?=htmlspecialchars($period['periodo'])?></strong><small><?=htmlspecialchars($period['numero_matricula'])?> · <?=htmlspecialchars($period['estado'])?></small></div><span><?=$period['asignaturas']?> asignaturas</span></summary>
  <div class="history-subjects">
  <?php foreach($period['subjects'] as $s):?>
   <details class="history-subject"><summary><div class="subject-main"><strong><?=htmlspecialchars($s['asignatura'])?></strong><small><?=htmlspecialchars($s['asignatura_codigo'])?> · <?=htmlspecialchars($s['nivel'])?> · Intento <?=$s['numero_intento']?></small></div><div class="subject-grade"><?php if($s['es_historico_q10']):?><span class="badge history">Q10 histórico</span><?php endif;?><b><?=$fmt($s['nota_final'])?></b><small>Nota final</small></div></summary>
    <div class="subject-body">
     <div class="grade-summary"><div><span>Ordinaria</span><strong><?=$fmt($s['nota_ordinaria'])?></strong></div><div><span>Supletorio</span><strong><?=$fmt($s['nota_supletorio'])?></strong></div><div><span>Final</span><strong><?=$fmt($s['nota_final'])?></strong></div><div><span>Inasistencias</span><strong><?=$s['inasistencias_acumuladas']===null?'—':htmlspecialchars((string)$s['inasistencias_acumuladas'])?></strong></div><div><span>Estado</span><strong><?=htmlspecialchars($s['estado'])?></strong></div></div>
     <?php if($s['observaciones_q10']||$s['observacion']):?><p class="history-note"><?=htmlspecialchars($s['observaciones_q10']?:$s['observacion'])?></p><?php endif;?>
     <?php if($s['details']):?><div class="table-scroll"><table class="grade-detail-table"><thead><tr><th>Parcial</th><th>Parámetro / recurso</th><th>Nota</th><th>Origen</th></tr></thead><tbody><?php foreach($s['details'] as $d):?><tr><td><?=htmlspecialchars($d['parcial']?:'Sin parcial')?></td><td><strong><?=htmlspecialchars($d['parametro']?:$d['recurso'])?></strong><?php if($d['parametro']&&$d['recurso']!==$d['parametro']):?><small><?=htmlspecialchars($d['recurso'])?></small><?php endif;?></td><td><strong><?=$fmt($d['nota_obtenida'])?></strong> / <?=$fmt($d['nota_maxima'])?></td><td><span class="badge history"><?=htmlspecialchars($d['origen_calificacion'])?></span></td></tr><?php endforeach;?></tbody></table></div><?php else:?><p class="muted">No existen componentes de evaluación registrados para esta asignatura.</p><?php endif;?>
    </div>
   </details>
  <?php endforeach;?>
  </div>
 </details>
 <?php endforeach;?>
</section>
<?php endforeach;?>
</div>
