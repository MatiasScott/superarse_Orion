<?php

declare(strict_types=1);

namespace App\Repositories;

use PDO;

final class MicrosoftIdentityRepository
{
    public function __construct(private PDO $db) {}
    public function provider(): array
    {
        $r = $this->db->query("SELECT id,codigo FROM proveedores_identidad WHERE codigo='MICROSOFT_ENTRA' AND activo=1 LIMIT 1")->fetch();
        if (!$r) throw new \RuntimeException('Proveedor MICROSOFT_ENTRA no configurado.');
        return $r;
    }
    public function accountByOid(string $oid, string $tenant): ?array
    {
        $p = $this->provider();
        $s = $this->db->prepare("SELECT ci.*,eci.permite_login,eci.codigo estado_codigo,u.activo usuario_activo,
            p.activo persona_activa,eu.permite_acceso,
            p.numero_identificacion,p.primer_nombre,p.segundo_nombre,p.primer_apellido,p.segundo_apellido
          FROM cuentas_institucionales ci
          JOIN estados_cuenta_institucional eci ON eci.id=ci.estado_cuenta_id
          JOIN usuarios u ON u.id=ci.usuario_id
          JOIN estados_usuario eu ON eu.id=u.estado_usuario_id
          JOIN personas p ON p.id=u.persona_id
          WHERE ci.proveedor_identidad_id=:prov AND ci.identificador_externo=:oid
            AND ci.tenant_id=:tenant AND ci.deleted_at IS NULL AND u.deleted_at IS NULL AND p.deleted_at IS NULL LIMIT 1");
        $s->execute(['prov' => $p['id'], 'oid' => $oid, 'tenant' => $tenant]);
        return $s->fetch() ?: null;
    }
    public function touchAccount(int $id): void
    {
        $this->db->prepare("UPDATE cuentas_institucionales SET ultima_sincronizacion_at=NOW() WHERE id=:id")->execute(['id' => $id]);
    }
    public function authTypeId(): int
    {
        $v = $this->db->query("SELECT id FROM tipos_autenticacion WHERE codigo='MICROSOFT_SSO' AND activo=1 LIMIT 1")->fetchColumn();
        if (!$v) throw new \RuntimeException('Tipo MICROSOFT_SSO no configurado.');
        return (int)$v;
    }
}
