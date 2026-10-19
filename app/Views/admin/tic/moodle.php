<?php
$u = rtrim((string)($_ENV['APP_URL'] ?? ''), '/');
$e = static fn (mixed $value): string => htmlspecialchars((string)$value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
?>
<div class="page-head"><div><span class="eyebrow">TIC · MOODLE</span><h1>Integración Moodle</h1><p>v0.11.3 · Vinculación confirmada de cursos (sin escrituras en Moodle)</p></div><a class="btn secondary" href="<?= $e($u) ?>/admin/tic">← TIC</a></div>
<?php if (!$enabled): ?><div class="alert">La integración Moodle está deshabilitada en .env.</div><?php endif; ?>
<?php if (!empty($linkNotice)): ?><div class="alert"><?= $e($linkNotice) ?></div><?php endif; ?>
<?php if ($error !== null): ?><div class="alert error">Error: <?= $e($error) ?></div><?php endif; ?>
<div class="card"><h2>Estado de conexión</h2>
<?php if ($site !== null): ?><p><strong>Conectado correctamente.</strong></p><table><tbody>
<tr><th>Sitio</th><td><?= $e($site['sitename'] ?? '-') ?></td></tr>
<tr><th>URL</th><td><?= $e($site['siteurl'] ?? '-') ?></td></tr>
<tr><th>Usuario técnico (ID)</th><td><?= $e($site['userid'] ?? '-') ?></td></tr>
<tr><th>Versión Moodle</th><td><?= $e($site['release'] ?? '-') ?></td></tr>
</tbody></table><?php endif; ?>
<p>No se muestran credenciales ni se crean categorías, cursos o matrículas.</p></div>
<div class="card"><h2>Superarse → Período → Campus → Escuela → Carrera → [Modalidad] → Nivel → Cursos</h2>
<form method="get" action="<?= $e($u) ?>/admin/tic/moodle"><label for="periodo">Período académico</label><select id="periodo" name="periodo" required><option value="">Seleccione...</option>
<?php foreach ($periods as $p): ?><option value="<?= (int)$p['id'] ?>" <?= isset($preview['period']['id']) && (int)$preview['period']['id'] === (int)$p['id'] ? 'selected' : '' ?>><?= $e($p['nombre']) ?> (<?= $e($p['codigo']) ?>) · <?= (int)$p['ofertas'] ?> ofertas</option><?php endforeach; ?></select><button class="btn" type="submit">Ver vista previa</button></form>
<?php if ($preview !== null): ?>
<h3><?= $e($preview['period']['nombre']) ?></h3>
<p><strong>Inventario Moodle:</strong> <?= (int)$preview['category_count'] ?> categorías · <?= (int)$preview['course_count'] ?> cursos. <strong>Raíz Superarse:</strong> <?= $preview['root_id'] === null ? 'No identificada' : '#'.(int)$preview['root_id'] ?>.</p>
<?php foreach ($preview['warnings'] as $w): ?><div class="alert error"><?= $e($w) ?></div><?php endforeach; ?>
<?php if (!$preview['rows']): ?><p>El período no tiene asignaturas con secciones activas.</p><?php endif; ?>
<?php foreach ($preview['rows'] as $row): ?>
<div class="card" style="margin-top:1rem"><h4><?= $e($row['display_name'] ?? $row['subject']['asignatura']) ?> <small>(<?= $e($row['subject']['asignatura_codigo']) ?>)</small></h4>
<p><strong>Oferta #<?= (int)$row['subject']['oferta_id'] ?></strong> · Clave propuesta: <code><?= $e($row['key']) ?></code></p>
<table><thead><tr><th>Ruta</th><th>Categoría</th><th>Estado</th></tr></thead><tbody>
<?php foreach ($row['segments'] as $segment): ?><tr><td><?= $e($segment['label']) ?></td><td><?= $e($segment['moodle_name'] ?? $segment['name']) ?><?php if (isset($segment['moodle_name']) && $segment['moodle_name'] !== $segment['name']): ?> <small>(Orion: <?= $e($segment['name']) ?>)</small><?php endif; ?></td><td><?= $segment['moodle_id'] === null ? $e($segment['status']) : 'Existe · #'.(int)$segment['moodle_id'] ?></td></tr><?php endforeach; ?>
</tbody></table>
<?php foreach ($row['blocked'] as $b): ?><p><strong>Requiere revisión:</strong> <?= $e($b) ?></p><?php endforeach; ?>
<p><strong>Estado de conciliación:</strong> <?= $e(str_replace('_', ' ', $row['course_status'])) ?> · <strong>Categoría de nivel:</strong> <?= $row['category_id'] === null ? 'Pendiente' : '#'.(int)$row['category_id'] ?></p>
<?php if ($row['saved_mapping']): ?><p><strong>Vinculado en Orion:</strong> curso Moodle #<?= (int)$row['saved_mapping']['moodle_course_id'] ?> · <?= $e($row['saved_mapping']['fullname_moodle']) ?></p><?php endif; ?>
<p><strong>Curso con clave exacta:</strong> <?= $row['course_id'] !== null ? '#'.(int)$row['course_id'] : 'No identificado' ?></p>
<?php if ($row['suggestions']): ?><details><summary>Posibles cursos existentes por nombre o código (<?= (int)$row['suggestion_total'] ?>) — requieren revisión manual</summary><ul><?php foreach ($row['suggestions'] as $s): ?><li>#<?= (int)$s['id'] ?> · <?= $e($s['name']) ?> · categoría #<?= (int)$s['category'] ?> · <?= $s['same_category'] ? 'MISMO NIVEL' : 'OTRA CATEGORÍA' ?> · <?= $s['name_match'] ? 'nombre coincide' : 'nombre distinto' ?><?= $s['code_match'] ? ' · código coincide' : '' ?>
<?php if (!$row['saved_mapping'] && !$row['blocked'] && $s['same_category'] && $s['name_match']): ?>
<form method="post" action="<?= $e($u) ?>/admin/tic/moodle/vincular" style="display:inline-block;margin-left:1rem" onsubmit="return confirm('¿Confirmar vinculación con el curso Moodle #<?= (int)$s['id'] ?>? No modificará Moodle.');">
<input type="hidden" name="_csrf" value="<?= $e(\App\Core\Csrf::token()) ?>">
<input type="hidden" name="periodo" value="<?= (int)$preview['period']['id'] ?>">
<input type="hidden" name="oferta_id" value="<?= (int)$row['subject']['oferta_id'] ?>">
<input type="hidden" name="asignatura_id" value="<?= (int)$row['subject']['asignatura_id'] ?>">
<input type="hidden" name="moodle_course_id" value="<?= (int)$s['id'] ?>">
<button class="btn small secondary" type="submit">Confirmar vínculo</button></form>
<?php endif; ?></li><?php endforeach; ?></ul></details><?php endif; ?>
</div>
<?php endforeach; ?>
<p><strong>Modo seguro:</strong> <?= $e($preview['notice']) ?></p>
<?php endif; ?></div>
