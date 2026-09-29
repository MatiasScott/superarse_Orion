<?php use App\Core\Csrf; $u=rtrim($_ENV['APP_URL']??'','/'); ?>
<div class="hero"><div><small>ORION</small><h1>Selecciona tu perfil</h1><p>Tu sesión puede operar con uno de tus perfiles activos.</p></div></div>
<div class="cards">
<?php foreach($profiles as $p): ?>
<article>
 <span><?=htmlspecialchars($p['codigo'])?></span><b><?=htmlspecialchars($p['nombre'])?></b>
 <small><?=htmlspecialchars($p['descripcion']??'')?></small>
 <form method="post" action="<?=$u?>/perfil" style="margin-top:16px">
  <input type="hidden" name="_csrf" value="<?=htmlspecialchars(Csrf::token())?>">
  <input type="hidden" name="perfil_id" value="<?=(int)$p['id']?>">
  <button class="btn" type="submit">Entrar</button>
 </form>
</article>
<?php endforeach; ?>
</div>
