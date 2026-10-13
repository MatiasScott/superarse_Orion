<?php
use App\Core\Csrf;
$u=rtrim($_ENV['APP_URL']??'','/');$h=static fn($v)=>htmlspecialchars((string)$v,ENT_QUOTES,'UTF-8');$money=static fn($v)=>'$'.number_format((float)$v,2);
$cancelled=($order['estado_codigo']??'')==='ANULADA';
?>
<div class="page-head"><div><span class="eyebrow">PORTAL DEL ESTUDIANTE</span><h1>Mi estado financiero</h1><p>Consulta tus cuotas, pagos y comprobantes.</p></div></div>
<?php if($flash):?><section class="card"><p><?=$h($flash)?></p></section><?php endif;?>
<?php if(!$orders):?><section class="card"><p>Todavía no tienes órdenes de pago registradas.</p></section><?php else:?>
<section class="card"><h2>Mis órdenes</h2><div class="table-scroll"><table><thead><tr><th>Orden</th><th>PAO</th><th>Total</th><th>Saldo</th><th>Estado</th></tr></thead><tbody>
<?php foreach($orders as$o):?><tr><td><a href="<?=$u?>/estudiante/financiero?id=<?=(int)$o['id']?>"><?=$h($o['numero_orden'])?></a></td><td><?=$h($o['periodo'].' · '.$o['carrera'])?></td><td><?=$money($o['total_pagar'])?></td><td><strong><?=$money($o['saldo_pendiente'])?></strong></td><td><?=$h($o['estado'])?></td></tr><?php endforeach;?></tbody></table></div></section>
<?php if($order):?>
<div class="stats"><div class="stat"><strong><?=$money($order['total_pagar'])?></strong><span>Total de la orden</span></div><div class="stat"><strong><?=$money((float)$order['total_pagar']-(float)$order['saldo_pendiente'])?></strong><span>Pagos aprobados</span></div><div class="stat"><strong><?=$money($order['saldo_pendiente'])?></strong><span>Saldo pendiente</span></div></div>
<section class="card"><h2>Cuotas de <?=$h($order['periodo'])?></h2><p>Los comprobantes pendientes de revisión no disminuyen tu saldo.</p><div class="table-scroll"><table><thead><tr><th>Cuota</th><th>Plazo</th><th>Valor original</th><th>Abonado</th><th>Saldo restante</th><th>Estado</th></tr></thead><tbody>
<?php foreach($installments as$c):?><tr><td><?=(int)$c['numero_cuota']?></td><td><?=$h($c['fecha_inicio_pago'])?> → <?=$h($c['fecha_fin_pago'])?></td><td><?=$money($c['monto_cuota'])?></td><td><?=$money($c['monto_pagado_aprobado'])?></td><td><strong><?=$money($c['saldo_cuota'])?></strong></td><td><?=$h($c['estado'])?></td></tr><?php endforeach;?></tbody></table></div></section>
<?php if(!$cancelled&&(float)$order['saldo_pendiente']>0):?>
<section class="card"><h2>Enviar comprobante de pago</h2><p>Saldo total pendiente: <strong><?=$money($order['saldo_pendiente'])?></strong>. Si pagas más de una cuota, Financiero distribuirá el excedente entre las siguientes cuotas pendientes al aprobarlo.</p>
<form method="post" enctype="multipart/form-data" action="<?=$u?>/estudiante/financiero/comprobante" class="form-grid"><input type="hidden" name="_csrf" value="<?=$h(Csrf::token())?>"><input type="hidden" name="orden_id" value="<?=(int)$order['id']?>">
<label>Cuota de referencia<select name="cuota_id" required><?php foreach($installments as$c):if(in_array($c['estado_codigo'],['PAGADA','ANULADA'],true))continue;?><option value="<?=(int)$c['id']?>">Cuota <?=(int)$c['numero_cuota']?> · saldo <?=$money($c['saldo_cuota'])?></option><?php endforeach;?></select></label>
<label>Monto pagado<input type="number" name="monto" min="0.01" step="0.01" required></label><label>Fecha del pago<input type="date" name="fecha_pago" value="<?=date('Y-m-d')?>" required></label>
<label>Medio de pago<select name="medio_pago_id" required><option value="">Selecciona...</option><?php foreach($media as$m):?><option value="<?=(int)$m['id']?>"><?=$h($m['nombre'])?></option><?php endforeach;?></select></label>
<label>Referencia<input name="referencia" maxlength="150"></label><label>Comprobante PDF/JPG/PNG (máximo 10 MB)<input type="file" name="comprobante" accept="application/pdf,image/jpeg,image/png" required></label><div><button class="btn" type="submit">Enviar para revisión</button></div></form></section>
<?php endif;?>
<section class="card"><h2>Mis comprobantes</h2><div class="table-scroll"><table><thead><tr><th>Pago</th><th>Monto</th><th>Estado</th><th>Distribución</th><th>Archivo</th><th>Observación</th></tr></thead><tbody>
<?php foreach($payments as$p):?><tr><td><?=$h($p['numero_pago'])?><br><small><?=$h($p['fecha_pago'])?></small></td><td><?=$money($p['monto_reportado'])?></td><td><?=$h($p['estado'])?></td><td><?=$h($p['distribucion']??'Pendiente de aprobación')?></td><td><?php if(!empty($p['comprobante_disponible'])):?><a href="<?=$u?>/estudiante/financiero/comprobante?pago_id=<?=(int)$p['id']?>" target="_blank" rel="noopener">Ver</a> · <a href="<?=$u?>/estudiante/financiero/comprobante?pago_id=<?=(int)$p['id']?>&amp;descargar=1">Descargar</a><?php endif;?></td><td><?=$h($p['motivo_rechazo']??$p['observacion']??'—')?></td></tr><?php endforeach;?><?php if(!$payments):?><tr><td colspan="6">No tienes comprobantes registrados.</td></tr><?php endif;?></tbody></table></div></section>
<?php endif;endif;?>
