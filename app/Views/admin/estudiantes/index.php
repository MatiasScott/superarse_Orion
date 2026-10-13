<?php $u = rtrim($_ENV['APP_URL'] ?? '', '/'); ?>
<div class="page-head">
    <div><span class="eyebrow">ESTUDIANTES</span>
        <h1>Estudiantes</h1>
        <p>Registro institucional creado desde procesos de admisión aprobados.</p>
    </div><a class="btn secondary" href="<?= $u ?>/admin/admisiones">Admisiones</a>
</div>
<form class="card search-bar" method="get"><input name="q" value="<?= htmlspecialchars($q) ?>" placeholder="Buscar por código, cédula, nombre o correo..."><button class="btn">Buscar</button></form>
<section class="card table-card">
    <div class="table-scroll">
        <table>
            <thead>
                <tr>
                    <th>Estudiante</th>
                    <th>Identificación</th>
                    <th>Cuenta institucional</th>
                    <th>Estado</th>
                    <th></th>
                </tr>
            </thead>
            <tbody><?php foreach ($students as $s): ?><tr>
                        <td>
                            <div class="cell-stack"><strong><?= htmlspecialchars($s['nombre']) ?></strong><small><?= htmlspecialchars($s['codigo_estudiante']) ?> · Ingreso <?= htmlspecialchars($s['fecha_ingreso'] ?: '—') ?></small></div>
                        </td>
                        <td><?= htmlspecialchars($s['numero_identificacion']) ?></td>
                        <td><?= htmlspecialchars($s['email_institucional'] ?: 'Pendiente de TIC') ?></td>
                        <td><span class="badge <?= $s['estado_codigo'] === 'ACTIVO' ? 'on' : '' ?>"><?= htmlspecialchars($s['estado']) ?></span></td>
                        <td><a class="btn secondary" href="<?= $u ?>/admin/estudiantes/ver?id=<?= $s['id'] ?>">Abrir ficha</a></td>
                    </tr><?php endforeach; ?><?php if (!$students): ?><tr>
                        <td colspan="5" class="empty">Aún no hay estudiantes.</td>
                    </tr><?php endif; ?></tbody>
        </table>
    </div>
</section>