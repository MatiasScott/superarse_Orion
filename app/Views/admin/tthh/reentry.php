<?php

use App\Core\Csrf;

$u = rtrim($_ENV['APP_URL'] ?? '', '/');

$e = static fn($v): string =>
htmlspecialchars((string)($v ?? ''), ENT_QUOTES, 'UTF-8');

$nombre = trim(implode(' ', array_filter([
    $employee['primer_nombre'] ?? '',
    $employee['segundo_nombre'] ?? '',
    $employee['primer_apellido'] ?? '',
    $employee['segundo_apellido'] ?? '',
])));

$ultimaFinalizacion = (string)($employee['fecha_fin_real'] ?? '');

$fechaMinima = $ultimaFinalizacion !== ''
    ? (new DateTimeImmutable($ultimaFinalizacion))
    ->modify('+1 day')->format('Y-m-d')
    : '';

$hoy = date('Y-m-d');

$puedeReingresar = $fechaMinima !== ''
    && $fechaMinima <= $hoy;

?>

<div class="page-head">
    <div>
        <small>TALENTO HUMANO</small>
        <h1>Reingreso laboral</h1>
        <p>
            Registra una nueva relación laboral conservando
            la ficha y el historial institucional del empleado.
        </p>
    </div>

    <a href="<?= $e($u) ?>/admin/tthh">
        ← Volver al personal
    </a>
</div>

<div class="form-card">
    <h2>Información del empleado</h2>

    <div class="form-grid">
        <p>
            <strong>Empleado:</strong>
            <?= $e($nombre) ?>
        </p>

        <p>
            <strong>Identificación:</strong>
            <?= $e($employee['numero_identificacion'] ?? '') ?>
        </p>

        <p>
            <strong>Código institucional:</strong>
            <?= $e($employee['codigo_empleado'] ?? '') ?>
        </p>

        <p>
            <strong>Relación anterior:</strong>
            #<?= (int)($employee['relacion_laboral_id'] ?? 0) ?>
        </p>

        <p>
            <strong>Estado anterior:</strong>
            <?= $e($employee['estado_codigo'] ?? '') ?>
        </p>

        <p>
            <strong>Última finalización:</strong>
            <?= $e($ultimaFinalizacion) ?>
        </p>
    </div>

    <p>
        La relación anterior permanecerá cerrada.
        El reingreso generará una nueva relación laboral,
        asignación principal e historial independiente.
    </p>
</div>

<?php if (!$puedeReingresar): ?>

    <div class="form-card">
        <h2>Reingreso todavía no disponible</h2>

        <p>
            La primera fecha posible de reingreso es
            <strong><?= $e($fechaMinima) ?></strong>.
        </p>

        <p>
            Orion todavía no permite registrar reingresos
            con fecha futura.
        </p>
    </div>

<?php else: ?>

    <form
        class="form-card"
        method="post"
        action="<?= $e($u) ?>/admin/tthh/reingreso/save">

        <input
            type="hidden"
            name="_csrf"
            value="<?= $e(Csrf::token()) ?>">

        <input
            type="hidden"
            name="empleado_id"
            value="<?= (int)$employee['id'] ?>">

        <h3>1. Clasificación institucional</h3>

        <div class="check-grid">
            <?php foreach ($personnelTypes as $x): ?>
                <label class="check">
                    <input
                        type="checkbox"
                        name="tipos_personal[]"
                        value="<?= (int)$x['id'] ?>">

                    <span>
                        <strong><?= $e($x['nombre']) ?></strong>
                        <small><?= $e($x['descripcion'] ?? '') ?></small>
                    </span>
                </label>
            <?php endforeach; ?>
        </div>

        <h3>2. Nueva relación laboral</h3>

        <div class="form-grid">

            <label>
                Fecha de reingreso

                <input
                    type="date"
                    name="fecha_inicio"
                    min="<?= $e($fechaMinima) ?>"
                    max="<?= $e($hoy) ?>"
                    value="<?= $e($hoy) ?>"
                    required>
            </label>

            <label>
                Fecha fin prevista

                <input
                    type="date"
                    name="fecha_fin_prevista">
            </label>

            <label>
                Tipo de contrato

                <select name="tipo_contrato_id">
                    <option value="0">No especificado</option>

                    <?php foreach ($contractTypes as $x): ?>
                        <option value="<?= (int)$x['id'] ?>">
                            <?= $e($x['nombre']) ?>
                        </option>
                    <?php endforeach; ?>
                </select>
            </label>

            <label>
                Jornada

                <select name="tipo_jornada_id">
                    <option value="0">No especificada</option>

                    <?php foreach ($workdayTypes as $x): ?>
                        <option value="<?= (int)$x['id'] ?>">
                            <?= $e($x['nombre']) ?>
                            <?php if (isset($x['horas_semanales'])): ?>
                                · <?= $e($x['horas_semanales']) ?> h
                            <?php endif; ?>
                        </option>
                    <?php endforeach; ?>
                </select>
            </label>

            <label>
                Número de contrato

                <input
                    name="numero_contrato"
                    maxlength="100">
            </label>

        </div>

        <h3>3. Nueva asignación principal</h3>

        <div class="form-grid">

            <label>
                Cargo

                <select name="cargo_id" required>
                    <option value="">Seleccione...</option>

                    <?php foreach ($positions as $x): ?>
                        <option value="<?= (int)$x['id'] ?>">
                            <?= $e($x['nombre']) ?>
                        </option>
                    <?php endforeach; ?>
                </select>
            </label>

            <label>
                Unidad / Área

                <select name="unidad_organizacional_id">
                    <option value="0">No especificada</option>

                    <?php foreach ($units as $x): ?>
                        <option value="<?= (int)$x['id'] ?>">
                            <?= $e($x['nombre']) ?>
                        </option>
                    <?php endforeach; ?>
                </select>
            </label>

            <label>
                Sede

                <select name="sede_id">
                    <option value="0">No especificada</option>

                    <?php foreach ($campuses as $x): ?>
                        <option value="<?= (int)$x['id'] ?>">
                            <?= $e($x['nombre']) ?>
                        </option>
                    <?php endforeach; ?>
                </select>
            </label>

        </div>

        <h3>4. Observaciones</h3>

        <label>
            Observación del reingreso

            <textarea
                name="observacion"
                rows="4"
                maxlength="1000"
                placeholder="Información complementaria del nuevo vínculo laboral"></textarea>
        </label>

        <p>
            Este proceso no crea automáticamente una cuenta
            Microsoft 365 ni modifica los accesos a Moodle.
        </p>

        <div>
            <button type="submit">
                Registrar reingreso laboral
            </button>
        </div>

    </form>

<?php endif; ?>