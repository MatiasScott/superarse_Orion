<?php $u = rtrim($_ENV['APP_URL'] ?? '', '/');
$canEdit = \App\Services\AccessService::can('estudiantes.editar'); ?>
<div class="page-head">
    <div><span class="eyebrow">ESTUDIANTE · <?= htmlspecialchars($student['codigo_estudiante']) ?></span>
        <h1><?= htmlspecialchars($student['nombre']) ?></h1>
        <p><?= htmlspecialchars($student['numero_identificacion']) ?></p>
    </div>
    <div class="page-actions"><a class="btn secondary" href="<?= $u ?>/admin/estudiantes">← Estudiantes</a><?php if (\App\Services\AccessService::can('academico.trayectorias.ver')): ?><a class="btn" href="<?= $u ?>/admin/academico/trayectoria?id=<?= $student['id'] ?>">Trayectoria académica</a><?php endif; ?><?php if(\App\Services\AccessService::can('academico.historial.ver')):?><a class="btn" href="<?=$u?>/admin/academico/historial?id=<?=$student['id']?>">Historial académico</a><?php endif;?></div>
</div>
<div class="detail-grid">
    <section class="card">
        <h2>Ficha institucional</h2>
        <dl class="detail-list">
            <dt>Estado</dt>
            <dd><?= htmlspecialchars($student['estado']) ?></dd>
            <dt>Fecha de ingreso</dt>
            <dd><?= htmlspecialchars($student['fecha_ingreso'] ?: '—') ?></dd>
            <dt>Cuenta</dt>
            <dd><?= htmlspecialchars($student['email_institucional'] ?: 'Pendiente de provisionamiento TIC') ?></dd>
        </dl>
    </section>
    <section class="card">
        <div class="page-head compact">
            <div>
                <h2>Ficha Situacional vigente</h2>
            </div><?php if ($canEdit): ?><a class="btn secondary" href="#socio-form">Actualizar ficha</a><?php endif; ?>
        </div>
        <?php if ($socio): ?><dl class="detail-list">
                <dt>Ocupación</dt>
                <dd><?= htmlspecialchars($socio['ocupacion'] ?: '—') ?></dd>
                <dt>Financiamiento</dt>
                <dd><?= htmlspecialchars($socio['financiamiento'] ?: '—') ?></dd>
                <dt>Ingresos hogar</dt>
                <dd><?= $socio['ingresos_hogar'] !== null ? '$ ' . number_format((float)$socio['ingresos_hogar'], 2) : '—' ?></dd>
                <dt>Miembros hogar</dt>
                <dd><?= htmlspecialchars((string)($socio['numero_miembros_hogar'] ?? '—')) ?></dd>
                <dt>Tipo colegio</dt>
                <dd><?= htmlspecialchars($socio['tipo_colegio'] ?: '—') ?></dd>
                <dt>Registrada</dt>
                <dd><?= htmlspecialchars($socio['vigente_desde']) ?></dd>
                <dt>Próxima actualización</dt>
                <dd><?= htmlspecialchars($socio['proxima_actualizacion']) ?></dd>
            </dl><?php else: ?><p class="muted">Aún no se ha registrado la Ficha Situacional.</p><?php endif; ?>
    </section>
</div>
<section class="card">
    <div class="page-head compact">
        <div>
            <h2>Contactos</h2>
        </div><?php if ($canEdit): ?><button class="btn secondary" type="button" id="openContact">Agregar contacto</button><?php endif; ?>
    </div>
    <div class="table-scroll">
        <table>
            <thead>
                <tr>
                    <th>Tipo</th>
                    <th>Nombre</th>
                    <th>Parentesco</th>
                    <th>Teléfono</th>
                    <th>Correo</th>
                </tr>
            </thead>
            <tbody><?php foreach ($contacts as $c): ?><tr>
                        <td><?= htmlspecialchars($c['tipo']) ?><?= $c['es_principal'] ? ' · Principal' : '' ?></td>
                        <td><?= htmlspecialchars(trim($c['nombres'] . ' ' . $c['apellidos'])) ?></td>
                        <td><?= htmlspecialchars($c['parentesco'] ?: '—') ?></td>
                        <td><?= htmlspecialchars($c['telefono'] ?: '—') ?></td>
                        <td><?= htmlspecialchars($c['correo'] ?: '—') ?></td>
                    </tr><?php endforeach; ?><?php if (!$contacts): ?><tr>
                        <td colspan="5" class="empty">Sin contactos registrados.</td>
                    </tr><?php endif; ?></tbody>
        </table>
    </div>
</section>
<section class="card">
    <h2>Historial de Ficha Situacional</h2>
    <p class="muted">Cada actualización conserva una versión histórica. La ficha vigente debe renovarse cada 6 meses según la política configurable del sistema.</p>
    <div class="table-scroll">
        <table>
            <thead>
                <tr>
                    <th>Registrada</th>
                    <th>Próxima actualización</th>
                    <th>Estado</th>
                    <th>Ocupación</th>
                    <th>Financiamiento</th>
                    <th>Ingresos hogar</th>
                    <th>Registrado por</th>
                    <th></th>
                </tr>
            </thead>
            <tbody><?php foreach ($socioHistory as $h): ?><tr>
                        <td><?= htmlspecialchars($h['vigente_desde']) ?></td>
                        <td><?= htmlspecialchars($h['proxima_actualizacion']) ?></td>
                        <td><?php $st = $h['estado_ficha']; ?><span class="badge <?= $st === 'VIGENTE' ? 'ok' : ($st === 'REQUIERE_ACTUALIZACION' ? 'warn' : 'off') ?>"><?= htmlspecialchars($st === 'VIGENTE' ? 'Vigente' : ($st === 'REQUIERE_ACTUALIZACION' ? 'Requiere actualización' : 'Histórica')) ?></span></td>
                        <td><?= htmlspecialchars($h['ocupacion'] ?: '—') ?></td>
                        <td><?= htmlspecialchars($h['financiamiento'] ?: '—') ?></td>
                        <td><?= $h['ingresos_hogar'] !== null ? '$ ' . number_format((float)$h['ingresos_hogar'], 2) : '—' ?></td>
                        <td><?= htmlspecialchars($h['registrado_por'] ?: 'Sistema') ?></td>
                        <td><button class="btn secondary socio-detail-btn" type="button" data-socio='<?= htmlspecialchars(json_encode($h, JSON_UNESCAPED_UNICODE | JSON_HEX_APOS | JSON_HEX_QUOT), ENT_QUOTES, "UTF-8") ?>'>Ver detalle</button></td>
                    </tr><?php endforeach; ?><?php if (!$socioHistory): ?><tr>
                        <td colspan="8" class="empty">Sin versiones de Ficha Situacional registradas.</td>
                    </tr><?php endif; ?></tbody>
        </table>
    </div>
</section>
<?php if ($canEdit): ?><section class="card socio-form-card" id="socio-form">
        <h2>Actualizar Ficha Situacional</h2>
        <p class="muted">Al guardar se conservará la ficha anterior como histórica y esta nueva versión será la vigente. Orion calculará automáticamente su próxima actualización.</p>
        <form method="post" action="<?= $u ?>/admin/estudiantes/socio/save"><input type="hidden" name="_csrf" value="<?= htmlspecialchars(\App\Core\Csrf::token()) ?>"><input type="hidden" name="estudiante_id" value="<?= $student['id'] ?>">
            <div class="form-grid socio-grid">
                <label><span>Ocupación</span><select name="ocupacion_id">
                        <option value="">Seleccione</option><?php foreach ($occupations as $x): ?><option value="<?= $x['id'] ?>"><?= htmlspecialchars($x['nombre']) ?></option><?php endforeach; ?>
                    </select></label>
                <label><span>Financiamiento</span><select name="financiamiento_id">
                        <option value="">Seleccione</option><?php foreach ($financing as $x): ?><option value="<?= $x['id'] ?>"><?= htmlspecialchars($x['nombre']) ?></option><?php endforeach; ?>
                    </select></label>
                <label><span>Formación padre</span><select name="nivel_padre_id">
                        <option value="">Seleccione</option><?php foreach ($familyEducation as $x): ?><option value="<?= $x['id'] ?>"><?= htmlspecialchars($x['nombre']) ?></option><?php endforeach; ?>
                    </select></label>
                <label><span>Formación madre</span><select name="nivel_madre_id">
                        <option value="">Seleccione</option><?php foreach ($familyEducation as $x): ?><option value="<?= $x['id'] ?>"><?= htmlspecialchars($x['nombre']) ?></option><?php endforeach; ?>
                    </select></label>
                <label><span>Ingresos del hogar</span><input type="number" min="0" step="0.01" name="ingresos_hogar"></label><label><span>Miembros del hogar</span><input type="number" min="1" name="miembros_hogar"></label>
                <label><span>Tipo de colegio</span><select name="tipo_colegio_id">
                        <option value="">Seleccione</option><?php foreach ($schoolTypes as $x): ?><option value="<?= $x['id'] ?>"><?= htmlspecialchars($x['nombre']) ?></option><?php endforeach; ?>
                    </select></label><label><span>Valor ayuda económica</span><input type="number" min="0" step="0.01" name="valor_ayuda"></label>
            </div>
            <div class="socio-checks"><label class="check"><input type="checkbox" name="recibe_bono" value="1"><span>Recibe Bono de Desarrollo Humano</span></label><label class="check"><input type="checkbox" name="tiene_ayuda" value="1"><span>Tiene ayuda económica</span></label></div>
            <div class="actions"><button class="btn">Guardar nueva vigencia</button></div>
        </form>
    </section><?php endif; ?>
<div class="orion-modal" id="contactModal" aria-hidden="true">
    <div class="orion-modal-backdrop" data-close></div>
    <div class="orion-modal-dialog"><button class="orion-modal-x" type="button" data-close>×</button><span class="eyebrow">ESTUDIANTE</span>
        <h2>Agregar contacto</h2>
        <form method="post" action="<?= $u ?>/admin/estudiantes/contacto/save"><input type="hidden" name="_csrf" value="<?= htmlspecialchars(\App\Core\Csrf::token()) ?>"><input type="hidden" name="estudiante_id" value="<?= $student['id'] ?>">
            <div class="form-grid"><label><span>Tipo</span><select name="tipo_contacto_id" required><?php foreach ($contactTypes as $x): ?><option value="<?= $x['id'] ?>"><?= htmlspecialchars($x['nombre']) ?></option><?php endforeach; ?></select></label><label><span>Nombres</span><input name="nombres" required></label><label><span>Apellidos</span><input name="apellidos"></label><label><span>Parentesco</span><input name="parentesco"></label><label><span>Teléfono</span><input name="telefono"></label><label><span>Correo</span><input type="email" name="correo"></label></div><label class="block-label"><span>Dirección</span><input name="direccion"></label><label class="check wide"><input type="checkbox" name="es_principal" value="1"><span>Contacto principal</span></label>
            <div class="modal-actions"><button class="btn secondary" type="button" data-close>Cancelar</button><button class="btn">Guardar contacto</button></div>
        </form>
    </div>
</div>
<div class="orion-modal" id="socioDetailModal" aria-hidden="true">
    <div class="orion-modal-backdrop" data-close></div>
    <div class="orion-modal-dialog socio-detail-dialog"><button class="orion-modal-x" type="button" data-close>×</button><span class="eyebrow">HISTORIAL · FICHA SITUACIONAL</span>
        <h2>Detalle de vigencia</h2>
        <dl class="detail-list" id="socioDetailList"></dl>
        <div class="modal-actions"><button class="btn secondary" type="button" data-close>Cerrar</button></div>
    </div>
</div>
<script>
    (() => {
        const wire = (m, b) => {
            if (!m || !b) return;
            const show = () => {
                    m.classList.add('is-open');
                    m.setAttribute('aria-hidden', 'false');
                    document.body.classList.add('modal-open')
                },
                hide = () => {
                    m.classList.remove('is-open');
                    m.setAttribute('aria-hidden', 'true');
                    document.body.classList.remove('modal-open')
                };
            b.addEventListener('click', show);
            m.querySelectorAll('[data-close]').forEach(x => x.addEventListener('click', hide));
        };
        wire(document.getElementById('contactModal'), document.getElementById('openContact'));
        const modal = document.getElementById('socioDetailModal'),
            list = document.getElementById('socioDetailList');
        const fields = [
            ['Registrada', 'vigente_desde'],
            ['Próxima actualización', 'proxima_actualizacion'],
            ['Estado', 'estado_ficha'],
            ['Ocupación', 'ocupacion'],
            ['Financiamiento', 'financiamiento'],
            ['Formación padre', 'formacion_padre'],
            ['Formación madre', 'formacion_madre'],
            ['Ingresos hogar', 'ingresos_hogar'],
            ['Miembros hogar', 'numero_miembros_hogar'],
            ['Tipo colegio', 'tipo_colegio'],
            ['Bono Desarrollo Humano', 'recibe_bono_desarrollo_humano'],
            ['Ayuda económica', 'tiene_ayuda_economica'],
            ['Valor ayuda', 'valor_ayuda_economica'],
            ['Registrado por', 'registrado_por'],
            ['Registrado el', 'created_at']
        ];
        document.querySelectorAll('.socio-detail-btn').forEach(btn => btn.addEventListener('click', () => {
            const d = JSON.parse(btn.dataset.socio || '{}');
            list.innerHTML = '';
            fields.forEach(([label, key]) => {
                const dt = document.createElement('dt'),
                    dd = document.createElement('dd');
                dt.textContent = label;
                let v = d[key];
                if (key === 'recibe_bono_desarrollo_humano' || key === 'tiene_ayuda_economica') v = Number(v) === 1 ? 'Sí' : 'No';
                dd.textContent = (v === null || v === '') ? '—' : String(v);
                list.append(dt, dd)
            });
            modal.classList.add('is-open');
            modal.setAttribute('aria-hidden', 'false');
            document.body.classList.add('modal-open')
        }));
        modal?.querySelectorAll('[data-close]').forEach(x => x.addEventListener('click', () => {
            modal.classList.remove('is-open');
            modal.setAttribute('aria-hidden', 'true');
            document.body.classList.remove('modal-open')
        }));
        document.addEventListener('keydown', e => {
            if (e.key === 'Escape') {
                document.querySelectorAll('.orion-modal.is-open').forEach(m => {
                    m.classList.remove('is-open');
                    m.setAttribute('aria-hidden', 'true')
                });
                document.body.classList.remove('modal-open')
            }
        })
    })();
</script>