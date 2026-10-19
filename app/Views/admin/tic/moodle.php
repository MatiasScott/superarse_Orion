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
<?php if ($row['suggestions'] && !$row['saved_mapping']): ?><details><summary>Posibles cursos existentes por nombre o código (<?= (int)$row['suggestion_total'] ?>) — requieren revisión manual</summary><ul><?php foreach ($row['suggestions'] as $s): ?><li>#<?= (int)$s['id'] ?> · <?= $e($s['name']) ?> · categoría #<?= (int)$s['category'] ?> · <?= $s['same_category'] ? 'MISMO NIVEL' : 'OTRA CATEGORÍA' ?> · <?= $s['name_match'] ? 'nombre coincide' : 'nombre distinto' ?><?= $s['code_match'] ? ' · código coincide' : '' ?>
<?php if (!$row['saved_mapping'] && !$row['blocked'] && $s['same_category'] && $s['name_match']): ?>
<form method="post" action="<?= $e($u) ?>/admin/tic/moodle/vincular" style="display:inline-block;margin-left:1rem" data-moodle-link-form="1" data-moodle-course-id="<?= (int)$s['id'] ?>">
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

<div class="orion-modal" id="moodleLinkModal" aria-hidden="true">
  <div class="orion-modal-backdrop" data-moodle-close></div>
  <div class="orion-modal-dialog" role="dialog" aria-modal="true" aria-labelledby="moodleLinkTitle">
    <button type="button" class="orion-modal-x" data-moodle-close aria-label="Cerrar">×</button>
    <span class="eyebrow">TIC · MOODLE</span>
    <h2 id="moodleLinkTitle">Confirmar vinculación</h2>
    <p>¿Deseas vincular la asignatura con el curso Moodle <strong id="moodleLinkCourse"></strong>?</p>
    <p class="muted">Solo se guardará la vinculación en Orion. No se modificará Moodle.</p>
    <div class="modal-actions">
      <button type="button" class="btn secondary" data-moodle-close>Cancelar</button>
      <button type="button" class="btn" id="moodleLinkAccept">Sí, confirmar vínculo</button>
    </div>
  </div>
</div>
<script>
(() => {
  'use strict';
  const modal = document.getElementById('moodleLinkModal');
  const accept = document.getElementById('moodleLinkAccept');
  const label = document.getElementById('moodleLinkCourse');
  if (!modal || !accept || !label) return;
  let formToSubmit = null, opener = null;
  function close() {
    modal.classList.remove('is-open');
    modal.setAttribute('aria-hidden', 'true');
    document.body.classList.remove('modal-open');
    formToSubmit = null;
    if (opener && opener.isConnected) opener.focus();
  }
  document.querySelectorAll('[data-moodle-link-form]').forEach(form => {
    form.addEventListener('submit', event => {
      event.preventDefault();
      formToSubmit = form;
      opener = event.submitter || form.querySelector('button');
      label.textContent = '#' + form.dataset.moodleCourseId;
      modal.classList.add('is-open');
      modal.setAttribute('aria-hidden', 'false');
      document.body.classList.add('modal-open');
      accept.focus();
    });
  });
  modal.querySelectorAll('[data-moodle-close]').forEach(x => x.addEventListener('click', close));
  document.addEventListener('keydown', event => {
    if (!modal.classList.contains('is-open')) return;
    if (event.key === 'Escape') { event.preventDefault(); close(); }
    if (event.key === 'Tab') {
      const controls = [...modal.querySelectorAll('button:not([disabled])')];
      const first = controls[0], last = controls[controls.length - 1];
      if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
      else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
    }
  });
  accept.addEventListener('click', () => {
    if (!formToSubmit) return;
    const form = formToSubmit;
    formToSubmit = null;
    accept.disabled = true;
    accept.textContent = 'Guardando…';
    form.submit();
  });
})();
</script>
