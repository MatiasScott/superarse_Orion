<?php $u=rtrim($_ENV['APP_URL']??'','/'); ?>
<div class="login">
 <div class="brand"><b>O</b><span><strong>Orion</strong><small>Superarse</small></span></div>
 <small>SIGA / ERP ACADÉMICO</small><h1>Bienvenido</h1>
 <p>Ingresa con tu cuenta institucional de Superarse.</p>
 <?php if($microsoftEnabled): ?>
   <a class="btn full" href="<?=$u?>/auth/microsoft">Continuar con Microsoft</a>
 <?php else: ?>
   <button class="btn full" disabled>Continuar con Microsoft</button>
   <div class="notice">Microsoft Entra ID aún no está habilitado en este entorno.</div>
 <?php endif; ?>
 <?php if($devEnabled): ?><p style="text-align:center"><a href="<?=$u?>/dev/login">Acceso local de desarrollo</a></p><?php endif; ?>
</div>
