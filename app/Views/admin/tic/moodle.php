<?php
$u = rtrim((string)($_ENV['APP_URL'] ?? ''), '/');
$e = static fn (mixed $value): string => htmlspecialchars((string)$value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
?>
<div class="page-head"><div><span class="eyebrow">TIC · MOODLE</span><h1>Integración Moodle</h1><p>Diagnóstico REST de solo lectura · Orion v0.11.0</p></div><a class="btn secondary" href="<?= $e($u) ?>/admin/tic">← TIC</a></div>
<?php if (!$enabled): ?><div class="alert">La integración Moodle está deshabilitada en .env.</div><?php endif; ?>
<?php if ($error !== null): ?><div class="alert error">No se pudo consultar Moodle: <?= $e($error) ?></div><?php endif; ?>
<div class="card">
<h2>Estado de la conexión</h2>
<?php if ($site !== null): ?>
<p><strong>Conectado correctamente.</strong> El servicio REST respondió sin excepciones.</p>
<table><tbody>
<tr><th>Sitio</th><td><?= $e($site['sitename'] ?? 'No disponible') ?></td></tr>
<tr><th>URL</th><td><?= $e($site['siteurl'] ?? 'No disponible') ?></td></tr>
<tr><th>Usuario técnico (ID)</th><td><?= $e($site['userid'] ?? 'No disponible') ?></td></tr>
<tr><th>Usuario</th><td><?= $e($site['username'] ?? 'No disponible') ?></td></tr>
<tr><th>Versión Moodle</th><td><?= $e($site['release'] ?? 'No disponible') ?></td></tr>
</tbody></table>
<?php elseif ($error === null): ?><p>Sin conexión activa.</p><?php endif; ?>
<p>Esta pantalla no crea usuarios, cursos, grupos ni matrículas. El token nunca se muestra.</p>
<a class="btn secondary" href="<?= $e($u) ?>/admin/tic/moodle">Volver a comprobar</a>
</div>
