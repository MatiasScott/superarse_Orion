<?php
declare(strict_types=1);
namespace App\Integrations\Moodle;

use PDO;
use RuntimeException;

/** Sincronización exclusivamente de categorías. Nunca mueve ni renombra categorías. */
final class MoodleCategorySync
{
    public function __construct(private PDO $db, private MoodleRestClient $moodle) {}

    private static function normalize(string $name): string
    {
        $name = mb_strtolower(trim($name), 'UTF-8');
        $name = strtr($name, ['á'=>'a','é'=>'e','í'=>'i','ó'=>'o','ú'=>'u','ü'=>'u','ñ'=>'n']);
        return trim(preg_replace('/[^a-z0-9]+/u', ' ', $name) ?? $name);
    }

    private static function displayName(array $segment): string
    {
        $name = trim((string)$segment['name']);
        return match ($segment['label']) {
            'Campus' => preg_match('/^campus\s+/iu', $name) ? $name : 'Campus '.$name,
            'Carrera' => mb_convert_case($name, MB_CASE_TITLE, 'UTF-8'),
            'Período' => preg_replace('/\s*-\s*/u', '-', $name) ?? $name,
            default => $name,
        };
    }

    /** Plan sin escrituras; no incluye categorías fuera de ofertas con secciones activas. */
    public function plan(array $preview): array
    {
        if (!$preview['root_id'] || $preview['warnings']) {
            throw new RuntimeException('La raíz Superarse es ambigua o faltante.');
        }
        $items = []; $dedup = [];
        foreach ($preview['rows'] as $row) {
            if ($row['blocked']) continue;
            $parentKey = 'id:'.(int)$preview['root_id'];
            foreach ($row['segments'] as $segment) {
                if ($segment['status'] === 'ambiguo') break;
                $name = self::displayName($segment);
                $key = $parentKey.'/'.self::normalize($name);
                if (!isset($dedup[$key])) {
                    $dedup[$key] = true;
                    $items[] = [
                        'key'=>$key, 'parent_key'=>$parentKey,
                        'name'=>$name, 'label'=>$segment['label'],
                        'existing_id'=>$segment['moodle_id'],
                    ];
                }
                $parentKey = $key;
            }
        }
        return $items;
    }

    /** Cada operación comprueba de nuevo la API; aborta ante nombres ambiguos. */
    public function execute(array $preview, int $periodId, ?int $actor): array
    {
        $plan = $this->plan($preview);
        if (count($plan) > 250) throw new RuntimeException('Plan demasiado grande; dividir por período.');
        $rootId = (int)$preview['root_id'];
        $resolved = ['id:'.$rootId => $rootId];
        $created = 0; $reused = 0;
        foreach ($plan as $item) {
            $parentId = $resolved[$item['parent_key']] ?? null;
            if (!$parentId) throw new RuntimeException('No se pudo determinar el padre de '.$item['name']);
            $categories = $this->moodle->categories();
            $matches = array_values(array_filter($categories, fn(array $cat): bool =>
                (int)($cat['parent'] ?? 0) === $parentId &&
                self::normalize((string)($cat['name'] ?? '')) === self::normalize($item['name'])
            ));
            if (count($matches) > 1) throw new RuntimeException('Categoría ambigua: '.$item['name'].' bajo #'.$parentId);
            if ($matches) {
                $id = (int)$matches[0]['id']; $action = 'REUTILIZADA'; $reused++;
            } else {
                // Límite por ejecución para reducir efectos ante interrupciones.
                if ($created >= 30) throw new RuntimeException('Límite de 30 categorías nuevas alcanzado; ejecutar nuevamente.');
                $idnumber = 'ORION-CAT-'.substr(hash('sha256', $item['key']), 0, 22);
                $response = $this->moodle->createCategory($item['name'], $parentId, $idnumber);
                $id = (int)$response['id']; $action = 'CREADA'; $created++;
            }
            $resolved[$item['key']] = $id;
            $stmt = $this->db->prepare('INSERT INTO orion_moodle_categoria_sync_log (periodo_academico_id, moodle_category_id, moodle_parent_id, nombre, accion, creado_por) VALUES (?,?,?,?,?,?)');
            $stmt->execute([$periodId,$id,$parentId,$item['name'],$action,$actor]);
        }
        return ['created'=>$created,'reused'=>$reused,'total'=>count($plan)];
    }
}
