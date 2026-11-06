<?php

use App\Core\Csrf;

$u = rtrim($_ENV['APP_URL'] ?? '', '/');
$e = static fn($v) => htmlspecialchars((string)($v ?? ''), ENT_QUOTES, 'UTF-8');

$nombre = trim(implode(' ', array_filter([
    $employee['primer_nombre'] ?? '',
    $employee['segundo_nombre'] ?? '',
    $employee['primer_apellido'] ?? '',
    $employee['segundo_apellido'] ?? '',
])));

$estadoActual = (string)($employee['estado_codigo'] ?? 'SIN ESTADO');

$acciones = [
    'PENDIENTE' => [
        'ACTIVA' => 'Activar relación',
        'ANULADA' => 'Anular relación',
    ],
    'ACTIVA' => [
        'SUSPENDIDA' => 'Suspender relación',
        'FINALIZADA' => 'Finalizar relación',
    ],
    'SUSPENDIDA' => [
        'ACTIVA' => 'Reactivar relación',
        'FINALIZADA' => 'Finalizar relación',
    ],
];

$disponibles = $acciones[$estadoActual] ?? [];
?>

<div class="page-head">
    <div>
        <small>TALENTO HUMANO</small>
        <h1>Movimientos laborales</h1>
        <p>Gestión de estados e historial de la relación laboral.</p>
    </div>
    <a href="<?= $e($u) ?>/admin/tthh">← Volver al personal</a>
</div>

<div class="form-card">
    <h2><?= $e($nombre) ?></h2>

    <p>
        <strong>Identificación:</strong>
        <?= $e($employee['numero_identificacion']) ?>
    </p>

    <p>
        <strong>Código:</strong>
        <?= $e($employee['codigo_empleado']) ?>
    </p>

    <p>
        <strong>Relación laboral:</strong>
        #<?= (int)$employee['relacion_laboral_id'] ?>
    </p>

    <p>
        <strong>Estado actual:</strong>
        <span class="badge <?= $estadoActual === 'ACTIVA' ? 'ok' : 'off' ?>">
            <?= $e($estadoActual) ?>
        </span>
    </p>

    <p>
        <strong>Inicio:</strong>
        <?= $e($employee['fecha_inicio']) ?>
    </p>

    <p>
        <strong>Finalización prevista:</strong>
        <?= $e($employee['fecha_fin_prevista'] ?: '—') ?>
    </p>
</div>

<?php if ($disponibles): ?>
    <div class="form-card">
        <h2>Registrar movimiento laboral</h2>

        <form method="post"
            action="<?= $e($u) ?>/admin/tthh/relacion/estado">

            <input type="hidden" name="_csrf"
                value="<?= $e(Csrf::token()) ?>">

            <input type="hidden" name="empleado_id"
                value="<?= (int)$employee['id'] ?>">

            <input type="hidden" name="relacion_laboral_id"
                value="<?= (int)$employee['relacion_laboral_id'] ?>">

            <label>
                Tipo de movimiento
                <select name="nuevo_estado" required>
                    <?php foreach ($disponibles as $codigo => $etiqueta): ?>
                        <option value="<?= $e($codigo) ?>">
                            <?= $e($etiqueta) ?>
                        </option>
                    <?php endforeach; ?>
                </select>
            </label>

            <label>
                Fecha efectiva
                <input type="date"
                    name="fecha_efectiva"
                    value="<?= date('Y-m-d') ?>"
                    min="<?= $e($employee['fecha_inicio']) ?>"
                    max="<?= date('Y-m-d') ?>"
                    required>
            </label>

            <label>
                Motivo
                <textarea name="motivo"
                    rows="4"
                    maxlength="255"
                    required></textarea>
            </label>

            <button type="submit"
                class="btn"
                onclick="return confirm('¿Confirmas el movimiento laboral?')">
                Registrar movimiento
            </button>
        </form>
    </div>
<?php endif; ?>

<div class="table-card">
    <h2>Historial de movimientos laborales</h2>

    <table>
        <thead>
            <tr>
                <th>Fecha efectiva</th>
                <th>Estado anterior</th>
                <th>Estado nuevo</th>
                <th>Motivo</th>
                <th>Registrado</th>
            </tr>
        </thead>
        <tbody>
            <?php foreach ($history as $movimiento): ?>
                <tr>
                    <td><?= $e($movimiento['fecha_efectiva'] ?: '—') ?></td>
                    <td><?= $e($movimiento['estado_anterior'] ?: '—') ?></td>
                    <td><?= $e($movimiento['estado_nuevo']) ?></td>
                    <td><?= $e($movimiento['motivo']) ?></td>
                    <td><?= $e($movimiento['changed_at']) ?></td>
                </tr>
            <?php endforeach; ?>

            <?php if (!$history): ?>
                <tr>
                    <td colspan="5" class="empty">
                        No existen movimientos registrados.
                    </td>
                </tr>
            <?php endif; ?>
        </tbody>
    </table>
</div>