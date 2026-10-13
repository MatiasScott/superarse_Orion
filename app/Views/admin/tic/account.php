<?php $u = rtrim($_ENV['APP_URL'] ?? '', '/'); ?>
<div class="page-head">
    <div><span class="eyebrow">TIC · CUENTA INSTITUCIONAL</span>
        <h1><?= htmlspecialchars($account['nombre']) ?></h1>
        <p><?= htmlspecialchars($account['email_institucional']) ?></p>
    </div><a class="btn secondary" href="<?= $u ?>/admin/tic/cuentas">← Cuentas</a>
</div>
<div class="detail-grid">
    <section class="card">
        <h2>Identidad</h2>
        <dl class="detail-list">
            <dt>Cédula</dt>
            <dd><?= htmlspecialchars($account['numero_identificacion']) ?></dd>
            <dt>Username</dt>
            <dd><?= htmlspecialchars($account['username']) ?></dd>
            <dt>Object ID Entra</dt>
            <dd><code><?= htmlspecialchars($account['identificador_externo']) ?></code></dd>
            <dt>Estado</dt>
            <dd><?= htmlspecialchars($account['estado']) ?></dd>
            <dt>Perfil(es)</dt>
            <dd><?= htmlspecialchars($account['perfiles'] ?: '—') ?></dd>
            <dt>Licencia(s)</dt>
            <dd><?= htmlspecialchars($account['licencias'] ?: '—') ?></dd>
        </dl>
    </section>
    <section class="card danger-soft">
        <h2>Acciones de acceso</h2>
        <p>Restablece la contraseña temporal configurada en Orion y obliga a cambiarla en el siguiente inicio. La contraseña no se guarda en la base de datos.</p><button class="btn" type="button" data-modal-open="reset-password-modal">Restablecer contraseña temporal</button>
    </section>
</div>
<section class="card">
    <h2>Historial de cuenta</h2>
    <div class="table-scroll">
        <table>
            <thead>
                <tr>
                    <th>Fecha</th>
                    <th>Evento</th>
                    <th>Ejecutado por</th>
                    <th>Detalle</th>
                </tr>
            </thead>
            <tbody><?php foreach ($events as $e): ?><tr>
                        <td><?= htmlspecialchars($e['created_at']) ?></td>
                        <td><?= htmlspecialchars($e['tipo']) ?></td>
                        <td><?= htmlspecialchars($e['actor'] ?: 'Sistema') ?></td>
                        <td><?= htmlspecialchars($e['detalle'] ?: '—') ?></td>
                    </tr><?php endforeach; ?><?php if (!$events): ?><tr>
                        <td colspan="4">Aún no hay eventos registrados para esta cuenta.</td>
                    </tr><?php endif; ?></tbody>
        </table>
    </div>
</section>
<div class="orion-modal" id="reset-password-modal" aria-hidden="true">
    <div class="orion-modal-backdrop" data-modal-close></div>

    <div
        class="orion-modal-dialog"
        role="dialog"
        aria-modal="true"
        aria-labelledby="resetPasswordTitle">
        <button
            type="button"
            class="orion-modal-x"
            data-modal-close
            aria-label="Cerrar">×</button>

        <span class="eyebrow">MICROSOFT 365</span>

        <h2 id="resetPasswordTitle">
            Restablecer contraseña
        </h2>

        <p>
            Se establecerá la contraseña temporal institucional y Microsoft
            obligará al usuario a cambiarla en el siguiente inicio.
        </p>

        <div class="modal-summary">
            <span>Cuenta</span>
            <strong>
                <?= htmlspecialchars($account['email_institucional']) ?>
            </strong>

            <span>Usuario</span>
            <strong>
                <?= htmlspecialchars($account['nombre']) ?>
            </strong>
        </div>

        <p class="muted">
            Orion no almacenará la contraseña temporal en la base de datos
            ni en el historial de la cuenta.
        </p>

        <div class="modal-actions">
            <button
                class="btn secondary"
                type="button"
                data-modal-close>
                Cancelar
            </button>

            <form
                id="resetPasswordForm"
                method="post"
                action="<?= $u ?>/admin/tic/cuenta/password-reset">
                <input
                    type="hidden"
                    name="_csrf"
                    value="<?= htmlspecialchars(\App\Core\Csrf::token()) ?>">

                <input
                    type="hidden"
                    name="id"
                    value="<?= (int) $account['id'] ?>">

                <button
                    class="btn"
                    id="confirmResetPassword"
                    type="submit">
                    Confirmar restablecimiento
                </button>
            </form>
        </div>
    </div>
</div>

<script>
    (() => {
        const modal = document.getElementById('reset-password-modal');
        const openButton = document.querySelector(
            '[data-modal-open="reset-password-modal"]'
        );
        const confirmButton = document.getElementById('confirmResetPassword');
        const form = document.getElementById('resetPasswordForm');

        if (!modal || !openButton || !confirmButton || !form) {
            return;
        }

        const show = () => {
            modal.classList.add('is-open');
            modal.setAttribute('aria-hidden', 'false');
            document.body.classList.add('modal-open');
        };

        const hide = () => {
            modal.classList.remove('is-open');
            modal.setAttribute('aria-hidden', 'true');
            document.body.classList.remove('modal-open');
        };

        openButton.addEventListener('click', show);

        modal.querySelectorAll('[data-modal-close]').forEach(button => {
            button.addEventListener('click', hide);
        });

        document.addEventListener('keydown', event => {
            if (event.key === 'Escape') {
                hide();
            }
        });

        form.addEventListener('submit', () => {
            confirmButton.disabled = true;
            confirmButton.textContent = 'Restableciendo…';
        });
    })();
</script>