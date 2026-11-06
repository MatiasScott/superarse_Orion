<?php

use App\Core\Csrf;

$employee = $employee ?? null;
$selectedTypes = $selectedTypes ?? [];
$selectedTypes = array_map('intval', $selectedTypes);
$isEdit = $employee !== null;

$e = static function ($value): string {
    return htmlspecialchars(
        (string)($value ?? ''),
        ENT_QUOTES,
        'UTF-8'
    );
};

$selected = static function ($field, $id) use ($employee): string {
    return (int)($employee[$field] ?? 0) === (int)$id
        ? 'selected'
        : '';
};

$u = rtrim($_ENV['APP_URL'] ?? '', '/'); ?>
<div class="page-head">
    <div>
        <small>TALENTO HUMANO</small>
        <h1><?= $isEdit ? 'Editar personal' : 'Registrar personal' ?></h1>
        <p>
            <?= $isEdit
                ? 'Actualiza la información del personal institucional.'
                : 'Registra la ficha laboral y solicita una cuenta a TIC si corresponde.' ?>
        </p>
    </div>
    <a href="<?= $e($u) ?>/admin/tthh">← Volver</a>
</div>
<form class="form-card" method="post" action="<?= $u ?>/admin/tthh/save"><input type="hidden" name="_csrf" value="<?= htmlspecialchars(Csrf::token()) ?>">
    <input
        type="hidden"
        name="id"
        value="<?= (int)($employee['id'] ?? 0) ?>">
    <h3>1. Datos personales</h3>
    <div class="form-grid">
        <label>Tipo de identificación
            <select name="tipo_identificacion_id" required>
                <option value="">Seleccione...</option><?php foreach ($types as $x): ?><option value="<?= $x['id'] ?>" <?= $selected('tipo_identificacion_id', $x['id']) ?>><?= htmlspecialchars($x['nombre']) ?></option><?php endforeach; ?>
            </select></label>
        <label>Número de identificación<input name="numero_identificacion" required maxlength="30" value="<?= $e($employee['numero_identificacion'] ?? '') ?>"></label>
        <label>Primer nombre
            <input name="primer_nombre" required maxlength="80" value="<?= $e($employee['primer_nombre'] ?? '') ?>"></label>
        <label>Segundo nombre
            <input name="segundo_nombre" maxlength="80" value="<?= $e($employee['segundo_nombre'] ?? '') ?>"></label>
        <label>Primer apellido
            <input name="primer_apellido" required maxlength="80" value="<?= $e($employee['primer_apellido'] ?? '') ?>"></label>
        <label>Segundo apellido
            <input name="segundo_apellido" maxlength="80" value="<?= $e($employee['segundo_apellido'] ?? '') ?>"></label>
    </div>
    <h3>2. Clasificación institucional</h3>
    <div class="check-grid">
        <?php foreach ($personnelTypes as $x): ?>
            <label class="check">
                <input type="checkbox" name="tipos_personal[]" value="<?= $x['id'] ?>" <?= in_array((int)$x['id'], $selectedTypes, true) ? 'checked' : '' ?>>
                <span>
                    <strong><?= htmlspecialchars($x['nombre']) ?></strong>
                    <small><?= htmlspecialchars($x['descripcion'] ?? '') ?></small>
                </span>
            </label>
        <?php endforeach; ?>
    </div>
    <h3>3. Relación laboral</h3>
    <div class="form-grid">
        <label>Fecha de inicio
            <input type="date" name="fecha_inicio" required value="<?= $e($employee['fecha_inicio'] ?? date('Y-m-d')) ?>">
        </label>
        <label>Fecha fin prevista
            <input type="date" name="fecha_fin_prevista" value="<?= $e($employee['fecha_fin_prevista'] ?? '') ?>">
        </label>
        <label>Estado de la relación laboral
            <select
                name="estado_relacion_id"
                required
                <?= $isEdit ? 'disabled' : '' ?>>
                <option value="">Seleccione...</option>
                <?php foreach ($states as $x): ?>
                    <option
                        value="<?= (int)$x['id'] ?>"
                        <?= $selected('estado_relacion_id', $x['id']) ?>>
                        <?= $e($x['nombre']) ?>
                    </option>
                <?php endforeach; ?>
            </select>

            <?php if ($isEdit): ?>
                <input
                    type="hidden"
                    name="estado_relacion_id"
                    value="<?= (int)$employee['estado_relacion_id'] ?>">
            <?php endif; ?>
        </label>
        <label>Tipo de contrato
            <select name="tipo_contrato_id">
                <option value="0">No especificado</option>
                <?php foreach ($contracts as $x): ?>
                    <option value="<?= $x['id'] ?>" <?= $selected('tipo_contrato_id', $x['id']) ?>><?= htmlspecialchars($x['nombre']) ?></option>
                <?php endforeach; ?>
            </select>
        </label>
        <label>Jornada
            <select name="tipo_jornada_id">
                <option value="0">No especificada</option>
                <?php foreach ($workdays as $x): ?>
                    <option value="<?= $x['id'] ?>" <?= $selected('tipo_jornada_id', $x['id']) ?>><?= htmlspecialchars($x['nombre']) ?><?= isset($x['horas_semanales']) && $x['horas_semanales'] !== null ? ' · ' . $x['horas_semanales'] . ' h' : '' ?></option>
                <?php endforeach; ?>
            </select>
        </label>
        <label>Número de contrato
            <input name="numero_contrato" maxlength="100">
        </label>
    </div>
    <h3>4. Asignación principal</h3>
    <?php if ($isEdit): ?>
        <div class="form-grid">
            <label>
                Fecha efectiva del cambio
                <input
                    type="date"
                    name="fecha_efectiva"
                    value="<?= date('Y-m-d') ?>"
                    required>
                <small>
                    Fecha desde la cual entra en vigor el cambio
                    de cargo, unidad, sede o clasificación.
                </small>
            </label>
        </div>
    <?php endif; ?>
    <div class="form-grid">
        <label>Cargo
            <select name="cargo_id" required>
                <option value="">Seleccione...</option>
                <?php foreach ($positions as $x): ?>
                    <option value="<?= $x['id'] ?>" <?= $selected('cargo_id', $x['id']) ?>><?= htmlspecialchars($x['nombre']) ?></option>
                <?php endforeach; ?>
            </select>
        </label>
        <label>Unidad / Área
            <select name="unidad_organizacional_id">
                <option value="0">No especificada</option>
                <?php foreach ($units as $x): ?>
                    <option value="<?= $x['id'] ?>" <?= $selected('unidad_organizacional_id', $x['id']) ?>><?= htmlspecialchars($x['nombre']) ?></option>
                <?php endforeach; ?>
            </select>
        </label>
        <label>Sede
            <select name="sede_id">
                <option value="0">No especificada</option>
                <?php foreach ($campuses as $x): ?>
                    <option value="<?= $x['id'] ?>" <?= $selected('sede_id', $x['id']) ?>><?= htmlspecialchars($x['nombre']) ?></option>
                <?php endforeach; ?>
            </select>
        </label>
    </div>
    <h3>5. Cuenta institucional</h3>

    <?php if (!$isEdit): ?>
        <label class="check wide">
            <input
                type="checkbox"
                name="solicitar_cuenta"
                value="1"
                checked>
            <span>
                <strong>Enviar solicitud de cuenta a TIC</strong>
                <small>
                    Orion registrará una solicitud pendiente.
                    No creará todavía la cuenta Microsoft 365.
                </small>
            </span>
        </label>
    <?php else: ?>
        <p class="form-help">
            Las cuentas institucionales se administran desde TIC.
            Editar esta ficha no modifica Microsoft 365.
        </p>
    <?php endif; ?>

    <label class="block-label">
        Observación
        <textarea
            name="observacion"
            rows="3"
            maxlength="3000"><?= $e($employee['observacion'] ?? '') ?></textarea>
    </label>
    <div class="actions">
        <a href="<?= $u ?>/admin/tthh">Cancelar</a>
        <button class="btn" type="submit">
            <?= $isEdit ? 'Guardar cambios' : 'Registrar personal' ?>
        </button>
    </div>
</form>