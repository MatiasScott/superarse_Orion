<?php

declare(strict_types=1);

namespace App\Integrations\Moodle;

/** Actividades base sin fechas, preguntas, archivos ni instrucciones inventadas. */
final class MoodleInstitutionalTemplate
{
    public static function activities(): array
    {
        return [
            [2, 'forum', 'FORO DE PRESENTACIÓN'],
            [3, 'url', ''], // Los enlaces reales los agrega el docente; no crear URL ficticia.
            [4, 'forum', 'FORO DE PARTICIPACIÓN: UNIDAD I'],
            [4, 'assign', 'TRABAJO AUTÓNOMO: UNIDAD I'],
            [4, 'assign', 'TRABAJO PRÁCTICO: UNIDAD I'],
            [4, 'quiz', 'EVALUACIÓN FORMATIVA: UNIDAD I'],
            [5, 'forum', 'FORO DE PARTICIPACIÓN: UNIDAD II'],
            [5, 'assign', 'TRABAJO AUTÓNOMO: UNIDAD II'],
            [5, 'assign', 'TRABAJO PRÁCTICO: UNIDAD II'],
            [5, 'quiz', 'EVALUACIÓN FORMATIVA: UNIDAD II'],
            [6, 'assign', 'ACTIVIDAD DE RECUPERACIÓN: PARCIAL I'],
            [7, 'quiz', 'EXAMEN PARCIAL I'],
            [9, 'forum', 'FORO DE PARTICIPACIÓN: UNIDAD III'],
            [9, 'assign', 'TRABAJO AUTÓNOMO: UNIDAD III'],
            [9, 'assign', 'TRABAJO PRÁCTICO: UNIDAD III'],
            [9, 'quiz', 'EVALUACIÓN FORMATIVA: UNIDAD III'],
            [10, 'forum', 'FORO DE PARTICIPACIÓN: UNIDAD IV'],
            [10, 'assign', 'TRABAJO AUTÓNOMO: UNIDAD IV'],
            [10, 'assign', 'TRABAJO PRÁCTICO: UNIDAD IV'],
            [10, 'quiz', 'EVALUACIÓN FORMATIVA: UNIDAD IV'],
            [11, 'assign', 'ACTIVIDAD DE RECUPERACIÓN: PARCIAL II'],
            [12, 'quiz', 'EXAMEN PARCIAL II'],
            [13, 'quiz', 'EXAMEN SUPLETORIO'],
        ];
    }

    /** Idempotencia: el plugin devuelve error específico ante actividades existentes. */
    public static function applyActivities(MoodleRestClient $client, int $courseId): array
    {
        $created = 0;
        $existing = 0;
        $errors = [];
        foreach (self::activities() as [$section, $type, $name]) {
            if ($name === '') continue;
            try {
                $client->templateActivity($courseId, $section, $type, $name);
                $created++;
            } catch (\Throwable $e) {
                $message = $e->getMessage();
                if (stripos($message, 'Ya existe una actividad del mismo tipo y nombre') !== false) {
                    $existing++;
                    continue;
                }
                $errors[] = $name . ': ' . $message;
            }
        }
        return ['created' => $created, 'existing' => $existing, 'errors' => $errors];
    }
}
