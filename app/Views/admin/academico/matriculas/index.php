<?php $u=rtrim($_ENV['APP_URL']??'','/'); ?>
<?php use App\Core\Csrf; ?>
<?php if(!empty($flash)):?><section class="card"><strong><?=htmlspecialchars($flash['type']==='error'?'Atención':'Operación completada')?></strong><p><?=htmlspecialchars($flash['message'])?></p></section><?php endif;?>
<div class="page-head"><div><span class="eyebrow">ACADÉMICO · MATRÍCULA</span><h1>Matrículas y renovación</h1><p>Busca al estudiante y genera una propuesta aplicando malla, prerrequisitos, historial e intentos.</p></div></div>
<section class="card"><form method="get" action="<?=$u?>/admin/academico/matriculas" class="form-grid"><label style="grid-column:1/-1">Identificación, código o nombre<input name="q" value="<?=htmlspecialchars($q)?>" placeholder="Ej. 1752335560 o Wendy Parco"></label><div><button class="btn">Buscar estudiante</button></div></form></section>
<?php if($q!==''):?><section class="card"><div class="section-head"><div><span class="eyebrow">RESULTADOS</span><h2>Estudiantes encontrados</h2></div></div><div class="table-scroll"><table><thead><tr><th>Identificación</th><th>Estudiante</th><th>Código</th><th>Trayectorias</th><th></th></tr></thead><tbody><?php foreach($students as $x):?><tr><td><?=htmlspecialchars($x['numero_identificacion'])?></td><td><strong><?=htmlspecialchars($x['nombre'])?></strong></td><td><code><?=htmlspecialchars($x['codigo_estudiante'])?></code></td><td><?=$x['trayectorias']?></td><td><a href="<?=$u?>/admin/academico/matriculas/estudiante?id=<?=$x['id']?>">Abrir</a></td></tr><?php endforeach;?><?php if(!$students):?><tr><td colspan="5">No se encontraron estudiantes.</td></tr><?php endif;?></tbody></table></div></section><?php endif;?>

<?php if(!empty($pending)):?>
<section class="card"><div class="section-head"><div><span class="eyebrow">CONFIRMACIÓN ACADÉMICA</span><h2>Matrículas pendientes</h2><p>La confirmación masiva respeta la habilitación financiera individual de cada estudiante.</p></div></div>
<form method="post" action="<?=$u?>/admin/academico/matriculas/confirmar-masivo"><input type="hidden" name="_csrf" value="<?=htmlspecialchars(Csrf::token())?>"><div class="table-scroll"><table><thead><tr><th></th><th>Matrícula</th><th>Estudiante</th><th>Carrera</th><th>Período</th><th>Asignaturas</th><th>Estado</th></tr></thead><tbody><?php foreach($pending as $m):?><tr><td><input type="checkbox" name="matriculas[]" value="<?=$m['id']?>"></td><td><a href="<?=$u?>/admin/academico/matriculas/ver?id=<?=$m['id']?>"><strong><?=htmlspecialchars($m['numero_matricula'])?></strong></a></td><td><?=htmlspecialchars($m['estudiante'])?><br><small><?=htmlspecialchars($m['codigo_estudiante'])?></small></td><td><?=htmlspecialchars($m['carrera'])?></td><td><?=htmlspecialchars($m['periodo'])?></td><td><?=$m['asignaturas']?></td><td><?=htmlspecialchars($m['estado'])?></td></tr><?php endforeach;?></tbody></table></div><button class="btn">Confirmar seleccionadas</button></form></section>
<?php endif;?>

<section class="card" id="historial-matriculas">
  <div class="section-head"><div><span class="eyebrow">CONSULTA INSTITUCIONAL</span><h2>Historial de matrículas</h2><p>Consulta matrículas de todos los estados sin alterar sus registros.</p></div></div>
  <form method="get" action="<?=$u?>/admin/academico/matriculas" class="form-grid">
    <label>Estudiante, código o matrícula<input name="buscar" value="<?=htmlspecialchars((string)$selectedFilters['buscar'])?>" placeholder="Nombre, EST-... u ORI-..."></label>
    <label>Estado<select name="estado"><option value="">Todos los estados</option><?php foreach($historyFilters['estados'] as $option):?><option value="<?=htmlspecialchars($option['codigo'])?>" <?=($selectedFilters['estado']===$option['codigo']?'selected':'')?>><?=htmlspecialchars($option['nombre'])?></option><?php endforeach;?></select></label>
    <label>PAO<select name="periodo"><option value="0">Todos los períodos</option><?php foreach($historyFilters['periodos'] as $option):?><option value="<?=(int)$option['id']?>" <?=((int)$selectedFilters['periodo']===(int)$option['id']?'selected':'')?>><?=htmlspecialchars($option['nombre'])?></option><?php endforeach;?></select></label>
    <label>Carrera<select name="carrera"><option value="0">Todas las carreras</option><?php foreach($historyFilters['carreras'] as $option):?><option value="<?=(int)$option['id']?>" <?=((int)$selectedFilters['carrera']===(int)$option['id']?'selected':'')?>><?=htmlspecialchars($option['nombre'])?></option><?php endforeach;?></select></label>
    <div><button class="btn" type="submit">Filtrar matrículas</button> <a href="<?=$u?>/admin/academico/matriculas#historial-matriculas">Limpiar filtros</a></div>
  </form>
  <p><strong><?=(int)$history['total']?></strong> matrícula(s) encontrada(s). Página <?=(int)$history['page']?> de <?=(int)$history['pages']?>.</p>
  <div class="table-scroll"><table><thead><tr><th>Matrícula</th><th>Estudiante</th><th>Carrera</th><th>PAO</th><th>Asignaturas</th><th>Estado</th><th>Detalle</th></tr></thead><tbody>
  <?php foreach($history['rows'] as $m):?><tr>
    <td><strong><?=htmlspecialchars($m['numero_matricula'])?></strong></td>
    <td><?=htmlspecialchars($m['estudiante'])?><br><small><?=htmlspecialchars($m['codigo_estudiante'])?></small></td>
    <td><?=htmlspecialchars($m['carrera'])?></td><td><?=htmlspecialchars($m['periodo'])?></td>
    <td><?=(int)$m['asignaturas']?></td><td><?=htmlspecialchars($m['estado'])?></td>
    <td><a href="<?=$u?>/admin/academico/matriculas/ver?id=<?=(int)$m['id']?>">Abrir</a></td>
  </tr><?php endforeach;?>
  <?php if(!$history['rows']):?><tr><td colspan="7">No hay matrículas para los filtros seleccionados.</td></tr><?php endif;?>
  </tbody></table></div>
  <?php if($history['pages']>1):?>
  <nav aria-label="Páginas del historial" style="display:flex;gap:1rem;align-items:center;margin-top:1rem">
  <?php $query=$selectedFilters; if($q!=='')$query['q']=$q; ?>
  <?php if($history['page']>1):$query['pagina']=$history['page']-1;?><a href="<?=$u?>/admin/academico/matriculas?<?=htmlspecialchars(http_build_query($query))?>#historial-matriculas">← Anterior</a><?php endif;?>
  <span>Página <?=(int)$history['page']?> / <?=(int)$history['pages']?></span>
  <?php if($history['page']<$history['pages']):$query['pagina']=$history['page']+1;?><a href="<?=$u?>/admin/academico/matriculas?<?=htmlspecialchars(http_build_query($query))?>#historial-matriculas">Siguiente →</a><?php endif;?>
  </nav><?php endif;?>
</section>
