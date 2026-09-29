<?php

declare(strict_types=1);

namespace App\Services;

use App\Core\Session;
use App\Repositories\{IdentityRepository, MicrosoftIdentityRepository};

final class MicrosoftAuthService
{
    public function __construct(private IdentityRepository $identity, private MicrosoftIdentityRepository $microsoft) {}
    public function login(array $claims, string $tenant): array
    {
        $a = $this->microsoft->accountByOid((string)$claims['oid'], $tenant);
        if (!$a) throw new \RuntimeException('Esta cuenta Microsoft no está vinculada a un usuario de Orion.');
        if (!$a['activo'] || !$a['permite_login'] || !$a['usuario_activo'] || !$a['persona_activa'] || !$a['permite_acceso'])
            throw new \RuntimeException('La cuenta institucional o el usuario no tienen acceso habilitado.');

        $uid = (int)$a['usuario_id'];
        $profiles = $this->identity->profiles($uid);
        if (!$profiles) throw new \RuntimeException('El usuario no tiene perfiles activos.');
        Session::regenerate();
        $profile = count($profiles) === 1 ? $profiles[0] : null;
        $uuid = self::uuid();
        $sid = $this->identity->createSession(
            $uid,
            $profile ? (int)$profile['id'] : null,
            $uuid,
            $this->microsoft->authTypeId(),
            (int)$a['proveedor_identidad_id']
        );
        $this->identity->touchLogin($uid);
        $this->microsoft->touchAccount((int)$a['id']);
        Session::set('auth_user', [
            'id' => $uid,
            'persona_id' => (int)$a['persona_id'],
            'identificacion' => $a['numero_identificacion'],
            'nombre' => trim($a['primer_nombre'] . ' ' . ($a['segundo_nombre'] ?? '') . ' ' . $a['primer_apellido'] . ' ' . ($a['segundo_apellido'] ?? '')),
            'email_institucional' => $a['email_institucional']
        ]);
        Session::set('db_session_id', $sid);
        Session::set('profiles', $profiles);
        if ($profile) (new AuthService($this->identity))->selectProfile((int)$profile['id'], false);
        return ['selected' => $profile];
    }
    private static function uuid(): string
    {
        $d = random_bytes(16);
        $d[6] = chr((ord($d[6]) & 15) | 64);
        $d[8] = chr((ord($d[8]) & 63) | 128);
        return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($d), 4));
    }
}
