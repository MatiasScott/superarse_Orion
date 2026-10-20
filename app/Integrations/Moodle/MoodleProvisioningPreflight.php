<?php
declare(strict_types=1);
namespace App\Integrations\Moodle;

use PDO;

/** Prevalidación de identidad. No crea ni modifica usuarios. */
final class MoodleProvisioningPreflight
{
    public function __construct(private PDO $db) {}

    public function inspect(array $student, array $identity): array
    {
        $result = ['ready'=>false, 'status'=>'Bloqueado', 'reasons'=>[], 'proposed_username'=>''];
        if ((int)($student['user_id'] ?? 0) < 1) $result['reasons'][]='Sin usuario activo en Orion';
        if (!empty($student['mappings'])) $result['reasons'][]='Ya existe mapeo Moodle';
        if ((int)($identity['id'] ?? 0) > 0) $result['reasons'][]='Existe un candidato Moodle; revisar y vincular';
        if (empty($identity['lookup_complete'])) $result['reasons'][]='No se completaron todas las consultas institucionales';
        $email = trim((string)($student['institutional_email'] ?? ''));
        if (!filter_var($email, FILTER_VALIDATE_EMAIL) || !str_ends_with(strtolower($email), '@superarse.edu.ec')) {
            $result['reasons'][]='Correo institucional ausente o inválido';
        }
        $username = trim((string)($student['institutional_username'] ?? ''));
        if (!preg_match('/^[a-z0-9][a-z0-9._-]{1,99}$/D', $username)) {
            $result['reasons'][]='Username institucional no válido para Moodle';
        } else {
            $result['proposed_username']=$username;
        }
        $stmt=$this->db->prepare('SELECT p.primer_nombre,p.primer_apellido,p.activo,p.deleted_at FROM estudiantes e JOIN personas p ON p.id=e.persona_id WHERE e.id=? LIMIT 1');
        $stmt->execute([(int)($student['student_id'] ?? 0)]);
        $person=$stmt->fetch(PDO::FETCH_ASSOC);
        if (!$person || !$person['activo'] || $person['deleted_at'] !== null || trim((string)$person['primer_nombre']) === '' || trim((string)$person['primer_apellido']) === '') {
            $result['reasons'][]='Datos personales incompletos o inactivos';
        }
        if (!$result['reasons']) {
            $result['status']='Prevalidación favorable · creación deshabilitada';
            $result['ready']=true;
        } else {
            $result['status']='Requiere revisión';
        }
        return $result;
    }
}
