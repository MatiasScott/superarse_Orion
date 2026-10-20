<?php
$u = rtrim((string)($_ENV['APP_URL'] ?? ''), '/');
$e = static fn (mixed $value): string => htmlspecialchars((string)$value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
?>
<div class="page-head"><div><span class="eyebrow">TIC · MOODLE</span><h1>Integración Moodle</h1><p>v0.11.22 · Sincronización controlada de grupos y paralelos</p></div><a class="btn secondary" href="<?= $e($u) ?>/admin/tic">← TIC</a></div>
<?php
$orionNotices = [];
if (!$enabled) $orionNotices[] = ['type' => 'warning', 'text' => 'La integración Moodle está deshabilitada en .env.'];
if (!empty($linkNotice)) {
    $noticeText = (string)$linkNotice;
    $isError = preg_match('/(?:\berrores?\s*:\s*[1-9]\d*|[1-9]\d*\s+errores?|no se |no fue |interrumpid|incidencias?\s*:\s*[1-9]\d*|plantilla quedó pendiente)/iu', $noticeText);
    $orionNotices[] = ['type' => $isError ? 'error' : 'success', 'text' => $noticeText];
}
if ($error !== null) $orionNotices[] = ['type' => 'error', 'text' => 'Error: '.(string)$error];
?>
<div class="card"><h2>Estado de conexión</h2>
<?php if ($site !== null): ?><p><strong>Conectado correctamente.</strong></p><table><tbody>
<tr><th>Sitio</th><td><?= $e($site['sitename'] ?? '-') ?></td></tr>
<tr><th>URL</th><td><?= $e($site['siteurl'] ?? '-') ?></td></tr>
<tr><th>Usuario técnico (ID)</th><td><?= $e($site['userid'] ?? '-') ?></td></tr>
<tr><th>Versión Moodle</th><td><?= $e($site['release'] ?? '-') ?></td></tr>
</tbody></table><?php endif; ?>
<p>No se muestran credenciales. La creación de categorías requiere confirmación; los cursos nuevos se crean ocultos y sin matrículas, previa confirmación.</p></div>
<div class="card"><h2>Superarse → Período → Campus → Escuela → Carrera → [Modalidad] → Nivel → Cursos</h2>
<form method="get" action="<?= $e($u) ?>/admin/tic/moodle"><label for="periodo">Período académico</label><select id="periodo" name="periodo" required><option value="">Seleccione...</option>
<?php foreach ($periods as $p): ?><option value="<?= (int)$p['id'] ?>" <?= isset($preview['period']['id']) && (int)$preview['period']['id'] === (int)$p['id'] ? 'selected' : '' ?>><?= $e($p['nombre']) ?> (<?= $e($p['codigo']) ?>) · <?= (int)$p['ofertas'] ?> ofertas</option><?php endforeach; ?></select><button class="btn" type="submit">Ver vista previa</button></form>
<?php if ($preview !== null): ?>
<h3><?= $e($preview['period']['nombre']) ?></h3>
<p><strong>Inventario Moodle:</strong> <?= (int)$preview['category_count'] ?> categorías · <?= (int)$preview['course_count'] ?> cursos. <strong>Raíz Superarse:</strong> <?= $preview['root_id'] === null ? 'No identificada' : '#'.(int)$preview['root_id'] ?>.</p>
<?php foreach ($preview['warnings'] as $w): $orionNotices[] = ['type' => 'warning', 'text' => (string)$w]; endforeach; ?>
<?php if (!$preview['rows']): ?><p>El período no tiene asignaturas con secciones activas.</p><?php endif; ?>
<?php
$syncPlan = [];
try { $syncPlan = (new \App\Integrations\Moodle\MoodleCategorySync(
    (new \App\Core\Database(new \App\Core\Config($_ENV)))->connection(),
    new \App\Integrations\Moodle\MoodleRestClient($_ENV)
))->plan($preview); } catch (\Throwable $ignored) {}
$missingCategories = array_values(array_filter($syncPlan, static fn($item) => $item['existing_id'] === null));
?>
<div class="card" style="margin:1rem 0">
  <h3>Plan de categorías para este período</h3>
  <p><?= count($syncPlan) ?> categorías en la ruta académica · <strong><?= count($missingCategories) ?> pendientes de creación</strong>. Las existentes se reutilizan.</p>
  <?php if ($missingCategories): ?><details><summary>Ver categorías pendientes</summary><ul>
  <?php foreach ($missingCategories as $item): ?><li><?= $e($item['label']) ?>: <?= $e($item['name']) ?></li><?php endforeach; ?>
  </ul></details><?php endif; ?>
  <?php if ($syncEnabled && $syncPlan && !$preview['warnings']): ?>
  <form method="post" action="<?= $e($u) ?>/admin/tic/moodle/sincronizar-categorias" id="moodleCategorySyncForm">
    <input type="hidden" name="_csrf" value="<?= $e(\App\Core\Csrf::token()) ?>">
    <input type="hidden" name="periodo" value="<?= (int)$preview['period']['id'] ?>">
    <input type="hidden" name="confirmacion" value="SINCRONIZAR">
    <button type="submit" class="btn" <?= !$missingCategories ? 'disabled' : '' ?>>Sincronizar categorías pendientes</button>
  </form>
  <?php elseif (!$syncEnabled): ?><p class="muted">Sincronización desactivada. Configure <code>MOODLE_SYNC_ENABLED=true</code> en .env solo cuando esté listo para autorizar escrituras.</p><?php endif; ?>
</div>
<?php foreach ($preview['rows'] as $row): ?>
<div class="card" style="margin-top:1rem"><h4><?= $e($row['display_name'] ?? $row['subject']['asignatura']) ?> <small>(<?= $e($row['subject']['asignatura_codigo']) ?>)</small></h4>
<p><strong>Oferta #<?= (int)$row['subject']['oferta_id'] ?></strong> · Clave propuesta: <code><?= $e($row['key']) ?></code></p>
<table><thead><tr><th>Ruta</th><th>Categoría</th><th>Estado</th></tr></thead><tbody>
<?php foreach ($row['segments'] as $segment): ?><tr><td><?= $e($segment['label']) ?></td><td><?= $e($segment['moodle_name'] ?? $segment['name']) ?><?php if (isset($segment['moodle_name']) && $segment['moodle_name'] !== $segment['name']): ?> <small>(Orion: <?= $e($segment['name']) ?>)</small><?php endif; ?></td><td><?= $segment['moodle_id'] === null ? $e($segment['status']) : 'Existe · #'.(int)$segment['moodle_id'] ?></td></tr><?php endforeach; ?>
</tbody></table>
<?php foreach ($row['blocked'] as $b): ?><p><strong>Requiere revisión:</strong> <?= $e($b) ?></p><?php endforeach; ?>
<p><strong>Estado de conciliación:</strong> <?= $e(str_replace('_', ' ', $row['course_status'])) ?> · <strong>Categoría de nivel:</strong> <?= $row['category_id'] === null ? 'Pendiente' : '#'.(int)$row['category_id'] ?></p>
<?php if ($row['saved_mapping'] && $syncEnabled): ?>
<div class="card" style="margin:1rem 0;padding:1rem;border:1px solid #cbd5e1">
<h5>Plantilla institucional Moodle · 13 secciones</h5>
<p>El botón de secciones se utiliza solo en cursos nuevos y vacíos. La comprobación final se hace en Moodle; no se modifica contenido docente existente.</p>
<form method="post" action="<?= $e($u) ?>/admin/tic/moodle/aplicar-plantilla" data-orion-template-confirm="Aplicar plantilla institucional al curso Moodle #<?= (int)$row['saved_mapping']['moodle_course_id'] ?>?">
<input type="hidden" name="_csrf" value="<?= $e(\App\Core\Csrf::token()) ?>">
<input type="hidden" name="periodo" value="<?= (int)$preview['period']['id'] ?>">
<input type="hidden" name="moodle_course_id" value="<?= (int)$row['saved_mapping']['moodle_course_id'] ?>">
<input type="hidden" name="confirmacion" value="APLICAR_PLANTILLA">
<button class="btn small" type="submit">Aplicar 13 secciones</button></form>
<h5 style="margin-top:1rem">Actividades institucionales automáticas</h5>
<p>Agrega las 22 actividades base (foros, tareas y cuestionarios) a las secciones ya creadas. No modifica las actividades existentes; los docentes completan fechas, contenidos y preguntas. Los módulos nuevos se crean ocultos.</p>
<form method="post" action="<?= $e($u) ?>/admin/tic/moodle/completar-actividades" data-orion-template-confirm="Completar las actividades institucionales faltantes en el curso Moodle #<?= (int)$row['saved_mapping']['moodle_course_id'] ?>?">
<input type="hidden" name="_csrf" value="<?= $e(\App\Core\Csrf::token()) ?>">
<input type="hidden" name="periodo" value="<?= (int)$preview['period']['id'] ?>">
<input type="hidden" name="moodle_course_id" value="<?= (int)$row['saved_mapping']['moodle_course_id'] ?>">
<input type="hidden" name="confirmacion" value="COMPLETAR_ACTIVIDADES">
<button class="btn small" type="submit">Completar actividades automáticamente</button>
</form>
<h5 style="margin-top:1rem">Agregar recurso o actividad</h5>
<p class="muted">Primero aplica la plantilla. Las actividades se crean ocultas, sin fechas ni preguntas. No se crean archivos ficticios.</p>
<form method="post" action="<?= $e($u) ?>/admin/tic/moodle/crear-actividad" data-orion-template-confirm="Crear este recurso o actividad en Moodle?">
<input type="hidden" name="_csrf" value="<?= $e(\App\Core\Csrf::token()) ?>">
<input type="hidden" name="periodo" value="<?= (int)$preview['period']['id'] ?>">
<input type="hidden" name="moodle_course_id" value="<?= (int)$row['saved_mapping']['moodle_course_id'] ?>">
<input type="hidden" name="confirmacion" value="CREAR_ACTIVIDAD">
<label>Sección</label><select name="sectionnum" required>
<?php foreach (['PARCIAL I','DOCUMENTOS IMPORTANTES','CLASES SINCRÓNICAS','UNIDAD I','UNIDAD 2','SEMANA DE RECUPERACIÓN: PARCIAL I','EXAMEN PARCIAL I','PARCIAL II','UNIDAD III','UNIDAD IV','SEMANA DE RECUPERACIÓN: PARCIAL II','EXAMEN PARCIAL II','EXAMEN SUPLETORIO'] as $idx=>$label): ?>
<option value="<?= $idx+1 ?>"><?= $idx+1 ?> · <?= $e($label) ?></option><?php endforeach; ?></select>
<label>Tipo</label><select name="type" required><option value="forum">Foro</option><option value="assign">Tarea</option><option value="quiz">Cuestionario</option><option value="url">Enlace URL</option></select>
<label>Nombre</label><input type="text" name="name" maxlength="255" minlength="3" required placeholder="Ej. EVALUACIÓN FORMATIVA 1.7: UNIDAD I">
<label>Enlace (solo para tipo URL)</label><input type="url" name="url" placeholder="https://...">
<button class="btn small secondary" type="submit">Crear actividad o recurso</button>
</form></div>
<?php endif; ?>
<?php if ($row['saved_mapping']): ?><p><strong>Vinculado en Orion:</strong> curso Moodle #<?= (int)$row['saved_mapping']['moodle_course_id'] ?> · <?= $e($row['saved_mapping']['fullname_moodle']) ?></p><?php endif; ?>
<p><strong>Curso con clave exacta:</strong> <?= $row['course_id'] !== null ? '#'.(int)$row['course_id'] : 'No identificado' ?></p>
<?php if (!$row['saved_mapping'] && !$row['blocked'] && $row['category_id'] &&
    $row['exact_count'] === 0 && $row['any_candidate_count'] === 0): ?>
<p><strong>Curso faltante:</strong> no hay coincidencias en Moodle. Se puede proponer un curso nuevo, inicialmente oculto.</p>
<?php if ($syncEnabled && !$preview['warnings']): ?>
<form method="post" action="<?= $e($u) ?>/admin/tic/moodle/crear-curso" data-moodle-create-course="1" data-course-name="<?= $e($row['display_name']) ?>" data-course-level="<?= (int)$row['category_id'] ?>">
<input type="hidden" name="_csrf" value="<?= $e(\App\Core\Csrf::token()) ?>">
<input type="hidden" name="periodo" value="<?= (int)$preview['period']['id'] ?>">
<input type="hidden" name="oferta_id" value="<?= (int)$row['subject']['oferta_id'] ?>">
<input type="hidden" name="asignatura_id" value="<?= (int)$row['subject']['asignatura_id'] ?>">
<input type="hidden" name="confirmacion" value="CREAR_CURSO">
<button type="submit" class="btn small">Crear curso en Moodle</button></form>
<?php else: ?><p class="muted">Creación deshabilitada. Requiere MOODLE_SYNC_ENABLED=true y permiso TIC de aprobación.</p><?php endif; ?>
<?php endif; ?>
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
<div class="card" style="margin-top:1rem">
<h5>Conciliación de paralelos con grupos Moodle (solo lectura)</h5>
<?php if (!$row['group_plan']): ?>
<p class="muted">No se encontraron secciones activas para esta asignatura.</p>
<?php else: ?>
<?php if ($row['group_read_error'] !== null): ?>
<p class="alert error">No fue posible consultar los grupos de este curso: <?= $e($row['group_read_error']) ?>. Verifica que el servicio incluya core_group_get_course_groups y que el usuario técnico tenga permisos.</p>
<?php elseif ($row['group_course_id']): ?>
<p class="muted">Grupos existentes consultados en Moodle: <?= (int)$row['remote_group_count'] ?>. La coincidencia de nombre no establece una vinculación.</p>
<?php else: ?><p class="muted">Vincula primero el curso Moodle para comparar sus grupos.</p><?php endif; ?>
<table><thead><tr><th>Sección Orion</th><th>Paralelo</th><th>Nombre propuesto del grupo</th><th>Comparación Moodle</th><th>Revisión Orion</th></tr></thead><tbody>
<?php foreach ($row['group_plan'] as $group): ?>
<tr><td>#<?= (int)$group['section_id'] ?> · <?= $e($group['section_code']) ?></td>
<td><?= $e($group['parallel_code'] !== '' ? $group['parallel_code'] : 'Sin asignar') ?></td>
<td><?= $e($group['group_name']) ?></td>
<td><?php if ($group['comparison_status'] === 'encontrado'): ?>Existe · grupo #<?= (int)$group['moodle_matches'][0]['id'] ?>
<?php elseif ($group['comparison_status'] === 'faltante'): ?>No existe en Moodle
<?php elseif ($group['comparison_status'] === 'ambiguo'): ?>Ambiguo: varios grupos con el mismo nombre
<?php elseif ($group['comparison_status'] === 'consulta_fallida'): ?>No disponible
<?php else: ?>Curso pendiente<?php endif; ?></td>
<td><?= $group['needs_review'] ? 'Revisar: '.$e($group['review_reason']) : 'Sin observaciones' ?>
<?php if ($syncEnabled && $row['saved_mapping'] && (int)$row['saved_mapping']['moodle_course_id'] === (int)$row['group_course_id'] && !$group['needs_review'] && in_array($group['comparison_status'], ['faltante','encontrado'], true)): ?>
<form method="post" action="<?= $e($u) ?>/admin/tic/moodle/sincronizar-grupo" data-orion-template-confirm="¿Sincronizar el grupo <?= $e($group['group_name']) ?> en el curso Moodle #<?= (int)$row['group_course_id'] ?>? No se matricularán usuarios.">
<input type="hidden" name="_csrf" value="<?= $e(\App\Core\Csrf::token()) ?>">
<input type="hidden" name="periodo" value="<?= (int)$preview['period']['id'] ?>">
<input type="hidden" name="moodle_course_id" value="<?= (int)$row['group_course_id'] ?>">
<input type="hidden" name="seccion_id" value="<?= (int)$group['section_id'] ?>">
<input type="hidden" name="confirmacion" value="SINCRONIZAR_GRUPO">
<button class="btn small" type="submit"><?= $group['comparison_status'] === 'faltante' ? 'Crear y vincular grupo' : 'Vincular grupo existente' ?></button>
</form>
<?php endif; ?>
</td></tr>
<?php endforeach; ?>
</tbody></table>
<?php endif; ?>
<p><strong>Curso destino:</strong> <?= $row['saved_mapping'] ? '#'.(int)$row['saved_mapping']['moodle_course_id'].' (vinculado)' : 'Pendiente de vinculación o creación' ?>.</p>
</div>
</div>
<?php endforeach; ?>
<p class="muted">Los grupos se sincronizan individualmente con confirmación. No se matriculan estudiantes ni docentes.</p>
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

<div class="orion-modal" id="moodleCategoryModal" aria-hidden="true">
  <div class="orion-modal-backdrop" data-category-close></div>
  <div class="orion-modal-dialog" role="dialog" aria-modal="true" aria-labelledby="moodleCategoryTitle">
    <button type="button" class="orion-modal-x" data-category-close aria-label="Cerrar">×</button>
    <span class="eyebrow">TIC · MOODLE</span>
    <h2 id="moodleCategoryTitle">Sincronizar categorías</h2>
    <p>Orion volverá a consultar Moodle y creará únicamente las categorías que falten en la jerarquía académica. No moverá categorías ni modificará cursos.</p>
    <p class="muted">La operación puede ser parcial si Moodle interrumpe la conexión. Los reintentos verifican los IDs existentes.</p>
    <div class="modal-actions"><button type="button" class="btn secondary" data-category-close>Cancelar</button>
      <button type="button" class="btn" id="moodleCategoryAccept">Sí, sincronizar categorías</button></div>
  </div>
</div>
<script>
(() => {
  const form = document.getElementById('moodleCategorySyncForm');
  const modal = document.getElementById('moodleCategoryModal');
  const accept = document.getElementById('moodleCategoryAccept');
  if (!form || !modal || !accept) return;
  const close = () => { modal.classList.remove('is-open'); modal.setAttribute('aria-hidden','true'); document.body.classList.remove('modal-open'); form.querySelector('button[type="submit"]').focus(); };
  form.addEventListener('submit', e => { e.preventDefault(); modal.classList.add('is-open'); modal.setAttribute('aria-hidden','false'); document.body.classList.add('modal-open'); accept.focus(); });
  modal.querySelectorAll('[data-category-close]').forEach(b => b.addEventListener('click', close));
  document.addEventListener('keydown', e => { if (modal.classList.contains('is-open') && e.key === 'Escape') close(); });
  accept.addEventListener('click', () => { accept.disabled = true; accept.textContent = 'Sincronizando…'; form.submit(); });
})();
</script>

<div class="orion-modal" id="moodleCreateCourseModal" aria-hidden="true">
  <div class="orion-modal-backdrop" data-create-course-close></div>
  <div class="orion-modal-dialog" role="dialog" aria-modal="true" aria-labelledby="moodleCreateCourseTitle">
    <button type="button" class="orion-modal-x" data-create-course-close aria-label="Cerrar">×</button>
    <span class="eyebrow">TIC · MOODLE</span>
    <h2 id="moodleCreateCourseTitle">Crear curso en Moodle</h2>
    <p>Curso: <strong id="moodleCreateCourseName"></strong></p>
    <p>Categoría de nivel: <strong id="moodleCreateCourseCategory"></strong></p>
    <p class="muted">Se creará un curso nuevo, inicialmente oculto, y se vinculará con Orion. No se matricularán estudiantes ni docentes. Esta acción modifica Moodle.</p>
    <div class="modal-actions"><button type="button" class="btn secondary" data-create-course-close>Cancelar</button><button type="button" class="btn" id="moodleCreateCourseAccept">Sí, crear curso</button></div>
  </div>
</div>
<script>
(() => {
  'use strict';
  const modal = document.getElementById('moodleCreateCourseModal');
  const accept = document.getElementById('moodleCreateCourseAccept');
  if (!modal || !accept) return;
  let pending = null, opener = null;
  const close = () => {
    modal.classList.remove('is-open'); modal.setAttribute('aria-hidden','true');
    document.body.classList.remove('modal-open'); pending = null;
    if (opener && opener.isConnected) opener.focus();
  };
  document.querySelectorAll('[data-moodle-create-course]').forEach(form => form.addEventListener('submit', e => {
    e.preventDefault(); pending = form; opener = e.submitter || form.querySelector('button');
    document.getElementById('moodleCreateCourseName').textContent = form.dataset.courseName;
    document.getElementById('moodleCreateCourseCategory').textContent = '#' + form.dataset.courseLevel;
    modal.classList.add('is-open'); modal.setAttribute('aria-hidden','false'); document.body.classList.add('modal-open'); accept.focus();
  }));
  modal.querySelectorAll('[data-create-course-close]').forEach(button => button.addEventListener('click', close));
  document.addEventListener('keydown', e => { if (e.key === 'Escape' && modal.classList.contains('is-open')) close(); });
  accept.addEventListener('click', () => { if (!pending) return; const form = pending; pending = null; accept.disabled = true; form.submit(); });
})();
</script>

<div class="orion-modal" id="orionTemplateModal" aria-hidden="true">
<div class="orion-modal-backdrop" data-orion-template-close></div>
<div class="orion-modal-dialog" role="dialog" aria-modal="true" aria-labelledby="orionTemplateTitle">
<button class="orion-modal-x" type="button" data-orion-template-close aria-label="Cerrar">×</button>
<h2 id="orionTemplateTitle">Confirmar operación Moodle</h2><p id="orionTemplateMessage"></p>
<p class="muted">La operación se realizará en el curso Moodle seleccionado.</p>
<div class="modal-actions"><button class="btn secondary" type="button" data-orion-template-close>Cancelar</button><button class="btn" type="button" id="orionTemplateAccept">Confirmar</button></div>
</div></div>
<script>
(()=>{const modal=document.getElementById('orionTemplateModal');const msg=document.getElementById('orionTemplateMessage');let form=null;
const close=()=>{modal.classList.remove('show','is-open','active');modal.style.display='none';modal.setAttribute('aria-hidden','true');form=null;};
document.querySelectorAll('[data-orion-template-confirm]').forEach(f=>f.addEventListener('submit',e=>{e.preventDefault();form=f;msg.textContent=f.dataset.orionTemplateConfirm;modal.style.display='flex';modal.classList.add('show','is-open','active');modal.setAttribute('aria-hidden','false');}));
modal.querySelectorAll('[data-orion-template-close]').forEach(b=>b.addEventListener('click',close));
document.getElementById('orionTemplateAccept').addEventListener('click',()=>{if(!form)return;const target=form;close();target.submit();});
document.addEventListener('keydown',e=>{if(e.key==='Escape')close();});})();
</script>

<style>
.orion-notice-dialog {max-width:480px;width:calc(100% - 32px);position:relative;}
.orion-notice-icon {font-size:2rem;margin:0 0 .4rem;line-height:1;}
.orion-notice-dialog[data-kind="success"] .orion-notice-icon {color:#16865a;}
.orion-notice-dialog[data-kind="error"] .orion-notice-icon {color:#b42318;}
.orion-notice-dialog[data-kind="warning"] .orion-notice-icon {color:#b76e00;}
.orion-notice-message {white-space:pre-wrap;overflow-wrap:anywhere;line-height:1.6;}
.orion-notice-progress {height:4px;background:#e2e8f0;border-radius:4px;overflow:hidden;margin-top:1rem;}
.orion-notice-progress > span {display:block;height:100%;background:#16865a;width:100%;transform-origin:left;}
.orion-notice-progress.is-running > span {animation:orion-notice-countdown 5s linear forwards;}
@keyframes orion-notice-countdown {to{transform:scaleX(0)}}
</style>
<div class="orion-modal" id="orionNoticeModal" aria-hidden="true">
  <div class="orion-modal-backdrop" data-notice-close></div>
  <div class="orion-modal-dialog orion-notice-dialog" role="alertdialog" aria-modal="true" aria-labelledby="orionNoticeTitle" aria-describedby="orionNoticeMessage" data-kind="success">
    <button type="button" class="orion-modal-x" data-notice-close aria-label="Cerrar mensaje">×</button>
    <div class="orion-notice-icon" id="orionNoticeIcon" aria-hidden="true">✓</div>
    <h2 id="orionNoticeTitle">Operación completada</h2>
    <p class="orion-notice-message" id="orionNoticeMessage"></p>
    <div class="orion-notice-progress" id="orionNoticeProgress"><span></span></div>
    <div class="modal-actions"><button type="button" class="btn" id="orionNoticeAccept">Aceptar</button></div>
  </div>
</div>
<script>
(() => {
  'use strict';
  const notices = <?= json_encode($orionNotices, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE) ?>;
  const modal = document.getElementById('orionNoticeModal');
  if (!modal || !Array.isArray(notices) || notices.length === 0) return;
  const dialog = modal.querySelector('.orion-notice-dialog');
  const title = document.getElementById('orionNoticeTitle');
  const message = document.getElementById('orionNoticeMessage');
  const icon = document.getElementById('orionNoticeIcon');
  const progress = document.getElementById('orionNoticeProgress');
  const accept = document.getElementById('orionNoticeAccept');
  let timer = null, index = 0, previousFocus = null;
  const labels = {
    success: ['Operación completada', '✓'],
    error: ['Se requiere revisión', '!'],
    warning: ['Atención', '!'],
    info: ['Información', 'i']
  };
  function close() {
    if (timer !== null) { clearTimeout(timer); timer = null; }
    progress.classList.remove('is-running');
    modal.classList.remove('is-open');
    modal.setAttribute('aria-hidden', 'true');
    document.body.classList.remove('modal-open');
    if (previousFocus && previousFocus.isConnected) previousFocus.focus();
    index += 1;
    if (index < notices.length) show();
  }
  function show() {
    const item = notices[index];
    const kind = Object.prototype.hasOwnProperty.call(labels, item.type) ? item.type : 'info';
    const autoClose = kind === 'success' || kind === 'info';
    previousFocus = document.activeElement;
    dialog.dataset.kind = kind;
    title.textContent = labels[kind][0];
    icon.textContent = labels[kind][1];
    message.textContent = String(item.text || '');
    progress.hidden = !autoClose;
    progress.classList.remove('is-running');
    modal.classList.add('is-open');
    modal.setAttribute('aria-hidden', 'false');
    document.body.classList.add('modal-open');
    accept.focus();
    if (autoClose) {
      void progress.offsetWidth;
      progress.classList.add('is-running');
      timer = setTimeout(close, 5000);
    }
  }
  accept.addEventListener('click', close);
  modal.querySelectorAll('[data-notice-close]').forEach(button => button.addEventListener('click', close));
  document.addEventListener('keydown', event => {
    if (!modal.classList.contains('is-open')) return;
    if (event.key === 'Escape') { event.preventDefault(); close(); }
    if (event.key === 'Tab') {
      event.preventDefault();
      accept.focus();
    }
  });
  show();
})();
</script>
