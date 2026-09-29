<?php use App\Services\AccessService;$u=rtrim($_ENV['APP_URL']??'','/');?>
<div class="page-head"><div><small>ADMINISTRACIÓN</small><h1>Usuarios</h1><p>Personas con acceso a Orion y sus perfiles institucionales.</p></div>
<?php if(AccessService::can('admin.usuarios.crear')):?><a class="btn" href="<?=$u?>/admin/usuarios/form">+ Nuevo usuario</a><?php endif;?></div>
<form class="toolbar" method="get"><input name="q" value="<?=htmlspecialchars($q)?>" placeholder="Buscar por identificación o nombre"><button class="btn">Buscar</button></form>
<div class="table-card"><table><thead><tr><th>Usuario</th><th>Identificación</th><th>Perfiles</th><th>Estado</th><th>Último acceso</th><th></th></tr></thead><tbody>
<?php foreach($users as $x):?><tr><td><strong><?=htmlspecialchars($x['nombre'])?></strong><small>#<?=(int)$x['id']?></small></td><td><?=htmlspecialchars($x['numero_identificacion'])?></td><td><?=htmlspecialchars($x['perfiles']??'Sin perfil')?></td>
<td><span class="badge <?=$x['permite_acceso']?'ok':'off'?>"><?=htmlspecialchars($x['estado_nombre'])?></span></td><td><?=htmlspecialchars($x['ultimo_acceso_at']??'Nunca')?></td>
<td><?php if(AccessService::can('admin.usuarios.editar')):?><a href="<?=$u?>/admin/usuarios/form?id=<?=(int)$x['id']?>">Editar</a><?php endif;?></td></tr><?php endforeach;?>
</tbody></table></div>
