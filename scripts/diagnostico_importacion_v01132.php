<?php
declare(strict_types=1);
/** Orion v0.11.32 Fase 2: diagnostico de esquema, SOLO LECTURA. */
use App\Core\Config;
use App\Core\Database;
use Dotenv\Dotenv;

define('BASE_PATH', dirname(__DIR__));
require BASE_PATH . '/vendor/autoload.php';
Dotenv::createImmutable(BASE_PATH)->safeLoad();
try {
    $pdo = (new Database(new Config($_ENV)))->connection();
    $tables = [
        'personas','estudiantes','estudiante_carreras','matriculas',
        'carreras','mallas','estados_estudiante','estados_trayectoria_academica',
        'becas','estudiante_becas','becas_estudiantes','tipos_beca',
        'datos_socioeconomicos','estudiante_datos_socioeconomicos',
        'fichas_socioeconomicas','habilitaciones_matricula',
        'estados_habilitacion_matricula','estados_habilitacion_financiera',
    ];
    echo "ORION v0.11.32 - ESQUEMA IMPORTACION (SOLO LECTURA)\n";
    echo "No muestra datos personales ni modifica tablas.\n";
    $found = [];
    foreach ($pdo->query('SHOW TABLES')->fetchAll(PDO::FETCH_COLUMN) as $name) {
        $lower = mb_strtolower((string)$name);
        if (in_array($lower, $tables, true) || str_contains($lower,'beca') || str_contains($lower,'socioeconom') || str_contains($lower,'discapacidad')) {
            $found[] = (string)$name;
        }
    }
    sort($found);
    foreach ($found as $name) {
        echo "\n=== {$name} ===\n";
        $quoted = '`'.str_replace('`','``',$name).'`';
        foreach ($pdo->query('SHOW COLUMNS FROM '.$quoted)->fetchAll(PDO::FETCH_ASSOC) as $column) {
            printf("%-38s %-27s NULL=%s KEY=%s\n",$column['Field'],$column['Type'],$column['Null'],$column['Key']);
        }
    }
    echo "\nFIN. No se ejecutaron escrituras.\n";
} catch (Throwable $e) {
    fwrite(STDERR, 'Error: '.$e->getMessage()."\n");
    exit(1);
}
