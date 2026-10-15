<?php
declare(strict_types=1);
namespace App\Integrations\Moodle;

use RuntimeException;

/** Cliente Moodle REST: sin operaciones de escritura en v0.11.0. */
final class MoodleRestClient
{
    private string $endpoint;
    private string $token;
    private int $timeout;

    public function __construct(array $env)
    {
        if (!filter_var($env['MOODLE_ENABLED'] ?? false, FILTER_VALIDATE_BOOL)) {
            throw new RuntimeException('La integración Moodle está deshabilitada (MOODLE_ENABLED).');
        }
        $base = trim((string)($env['MOODLE_BASE_URL'] ?? ''));
        $token = trim((string)($env['MOODLE_TOKEN'] ?? ''));
        if ($base === '' || $token === '') {
            throw new RuntimeException('Faltan MOODLE_BASE_URL o MOODLE_TOKEN en .env.');
        }
        $parts = parse_url($base);
        if (!is_array($parts) || strtolower($parts['scheme'] ?? '') !== 'https' || empty($parts['host']) || isset($parts['user']) || isset($parts['pass']) || isset($parts['query']) || isset($parts['fragment'])) {
            throw new RuntimeException('MOODLE_BASE_URL debe ser una URL HTTPS válida sin credenciales ni parámetros.');
        }
        $this->endpoint = rtrim($base, '/') . '/webservice/rest/server.php';
        $this->token = $token;
        $this->timeout = max(3, min(60, (int)($env['MOODLE_TIMEOUT'] ?? 30)));
    }

    public function siteInfo(): array
    {
        return $this->read('core_webservice_get_site_info');
    }

    public function categories(): array
    {
        return $this->read('core_course_get_categories');
    }

    public function courses(): array
    {
        return $this->read('core_course_get_courses');
    }

    private function read(string $function): array
    {
        if (!function_exists('curl_init')) {
            throw new RuntimeException('La extensión PHP cURL no está habilitada.');
        }
        $ch = curl_init($this->endpoint);
        if ($ch === false) {
            throw new RuntimeException('No fue posible iniciar la conexión Moodle.');
        }
        try {
            curl_setopt_array($ch, [
                CURLOPT_POST => true,
                CURLOPT_POSTFIELDS => http_build_query([
                    'wstoken' => $this->token,
                    'wsfunction' => $function,
                    'moodlewsrestformat' => 'json',
                ]),
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_CONNECTTIMEOUT => min(10, $this->timeout),
                CURLOPT_TIMEOUT => $this->timeout,
                CURLOPT_FOLLOWLOCATION => false,
                CURLOPT_SSL_VERIFYPEER => true,
                CURLOPT_SSL_VERIFYHOST => 2,
                CURLOPT_HTTPHEADER => ['Accept: application/json'],
            ]);
            $response = curl_exec($ch);
            if ($response === false) {
                throw new RuntimeException('Error de conexión Moodle: ' . curl_error($ch));
            }
            $http = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
            if ($http !== 200) {
                throw new RuntimeException('Moodle respondió HTTP ' . $http . '.');
            }
            $data = json_decode($response, true);
            if (!is_array($data)) {
                throw new RuntimeException('Moodle no devolvió JSON válido.');
            }
            if (isset($data['exception'])) {
                $code = (string)($data['errorcode'] ?? $data['exception']);
                $message = (string)($data['message'] ?? 'Error desconocido');
                throw new RuntimeException('Moodle (' . $code . '): ' . $message);
            }
            return $data;
        } finally {
            curl_close($ch);
        }
    }
}
