<?php use App\Core\Csrf; $u=rtrim($_ENV['APP_URL']??'','/'); ?>
<div class="login">
 <div class="brand"><b>O</b><span><strong>Orion</strong><small>Desarrollo local</small></span></div>
 <h1>Acceso local</h1>
 <p>Disponible únicamente con APP_ENV=local.</p>
 <?php if(!empty($error)): ?><div class="notice"><?=htmlspecialchars($error)?></div><?php endif; ?>
 <form method="post" action="<?=$u?>/dev/login">
  <input type="hidden" name="_csrf" value="<?=htmlspecialchars(Csrf::token())?>">
  <label>Identificación</label><input name="identificacion" required>
  <label>Clave DEV_LOGIN_KEY</label><input type="password" name="dev_key" required>
  <button class="btn full" type="submit">Ingresar</button>
 </form>
 <hr>
 <h3>Crear administrador inicial</h3>
 <form method="post" action="<?=$u?>/dev/bootstrap">
  <input type="hidden" name="_csrf" value="<?=htmlspecialchars(Csrf::token())?>">
  <label>Identificación</label><input name="identificacion" required maxlength="30">
  <label>Primer nombre</label><input name="primer_nombre" required maxlength="80">
  <label>Primer apellido</label><input name="primer_apellido" required maxlength="80">
  <label>Clave DEV_LOGIN_KEY</label><input type="password" name="dev_key" required>
  <button class="btn full" type="submit">Crear Super Administrador</button>
 </form>
</div>
