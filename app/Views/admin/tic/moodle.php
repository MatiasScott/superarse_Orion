<?php
$u = rtrim((string)($_ENV['APP_URL'] ?? ''), '/');
$e = static fn (mixed $value): string => htmlspecialchars((string)$value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
?>
<div class="page-head"><div><span class="eyebrow">TIC · MOODLE</span><h1>Integración Moodle</h1><p>v0.11.1 · Vista previa académica (solo lectura)</p></div><a class="btn secondary" href="<?= $e($u) ?>/admin/tic">← TIC</a></div>
<?php if (!$enabled): ?><div class="alert">La integración Moodle está deshabilitada en .env.</div><?php endif; ?>
<?php if ($error !== null): ?><div class="alert error">No se pudo preparar el diagnóstico: <?= $e($error) ?></div><?php endif; ?>
<div class="card">
<h2>Estado de conexión</h2>
<?php if ($site !== null): ?>
<p><strong>Conectado correctamente.</strong></p>
<table><tbody>
<tr><th>Sitio</th><td><?= $e($site['sitename'] ?? 'No disponible') ?></td></tr>
<tr><th>URL</th><td><?= $e($site['siteurl'] ?? 'No disponible') ?></td></tr>
<tr><th>Usuario técnico (ID)</th><td><?= $e($site['userid'] ?? 'No disponible') ?></td></tr>
<tr><th>Versión Moodle</th><td><?= $e($site['release'] ?? 'No disponible') ?></td></tr>
</tbody></table>
<?php endif; ?>
<p>Esta pantalla no crea categorías, cursos, grupos ni matrículas. El token nunca se muestra.</p>
</div>
<div class="card">
<h2>Estructura académica: Período → Carrera → Asignatura</h2>
<p>Seleccione un período para comparar las ofertas y secciones activas de Orion con los cursos y categorías existentes en Moodle.</p>
<form method="get" action="<?= $e($u) ?>/admin/tic/moodle">
<label for="periodo">Período académico</label>
<select id="periodo" name="periodo" required>
<option value="">Seleccione...</option>
<?php foreach ($periods as $period): ?>
<option value="<?= (int)$period['id'] ?>" <?= isset($preview['period']['id']) && (int)$preview['period']['id'] === (int)$period['id'] ? 'selected' : '' ?>><?= $e($period['nombre']) ?> (<?= $e($period['codigo']) ?>) · <?= (int)$period['ofertas'] ?> ofertas</option>
<?php endforeach; ?>
</select>
<button class="btn" type="submit">Ver vista previa</button>
</form>
<?php if ($preview !== null): ?>
<h3><?= $e($preview['period']['nombre']) ?></h3>
<p><strong>Categoría período:</strong> <code><?= $e($preview['period_key']) ?></code> — <?= $preview['period_exists'] ? 'Existe en Moodle' : 'Pendiente de creación' ?></p>
<p><strong>Carreras:</strong> <?= count($preview['careers']) ?> · <strong>Asignaturas con secciones activas:</strong> <?= (int)$preview['subjects_total'] ?></p>
<?php foreach ($preview['careers'] as $entry): ?>
<h4><?= $e($entry['career']['nombre']) ?> — <?= $entry['exists'] ? 'Categoría existente' : 'Categoría pendiente' ?></h4>
<p><code><?= $e($entry['key']) ?></code></p>
<?php if ($entry['subjects']): ?>
<table><thead><tr><th>Asignatura</th><th>Código Orion</th><th>Clave de curso Moodle</th><th>Estado</th></tr></thead><tbody>
<?php foreach ($entry['subjects'] as $subject): ?>
<tr><td><?= $e($subject['name']) ?></td><td><?= $e($subject['code']) ?></td><td><code><?= $e($subject['key']) ?></code></td><td><?= $subject['exists'] ? 'Existente' : 'Pendiente' ?></td></tr>
<?php endforeach; ?>
</tbody></table>
<?php else: ?><p>No hay secciones activas para esta carrera en el período.</p><?php endif; ?>
<?php endforeach; ?>
<p><strong>Modo seguro:</strong> vista previa únicamente. No se realizan cambios en Moodle ni en Orion.</p>
<?php endif; ?>
</div>
