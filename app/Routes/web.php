<?php

declare(strict_types=1);

use App\Controllers\{DashboardController, HealthController, HomeController, ProfileController};
use App\Controllers\Auth\{DevAuthController, LoginController};
use App\Controllers\Admin\IdentityAdminController;
use App\Controllers\Admin\HumanResourcesController;
use App\Controllers\Auth\MicrosoftAuthController;

$router->get(
    '/',
    [HomeController::class, 'index']
);
$router->get(
    '/login',
    [LoginController::class, 'show']
);
$router->get(
    '/health',
    [HealthController::class, 'index']
);
$router->get(
    '/dev/login',
    [DevAuthController::class, 'form']
);
$router->post(
    '/dev/login',
    [DevAuthController::class, 'login']
);
$router->post(
    '/dev/bootstrap',
    [DevAuthController::class, 'bootstrap']
);
$router->post(
    '/logout',
    [DevAuthController::class, 'logout']
);
$router->get(
    '/perfil',
    [ProfileController::class, 'index']
);
$router->post(
    '/perfil',
    [ProfileController::class, 'select']
);
$router->get(
    '/dashboard',
    [DashboardController::class, 'index']
);

$router->get(
    '/admin/usuarios',
    [IdentityAdminController::class, 'users']
);
$router->get(
    '/admin/usuarios/form',
    [IdentityAdminController::class, 'userForm']
);
$router->post(
    '/admin/usuarios/save',
    [IdentityAdminController::class, 'userSave']
);
$router->get(
    '/admin/roles',
    [IdentityAdminController::class, 'roles']
);
$router->get(
    '/admin/roles/form',
    [IdentityAdminController::class, 'roleForm']
);
$router->post(
    '/admin/roles/save',
    [IdentityAdminController::class, 'roleSave']
);
$router->get(
    '/admin/permisos',
    [IdentityAdminController::class, 'permissions']
);
$router->get(
    '/admin/roles/permisos',
    [IdentityAdminController::class, 'rolePermissions']
);
$router->post(
    '/admin/roles/permisos/save',
    [IdentityAdminController::class, 'rolePermissionsSave']
);
$router->get(
    '/auth/microsoft',
    [MicrosoftAuthController::class, 'redirect']
);
$router->get(
    '/auth/microsoft/callback',
    [MicrosoftAuthController::class, 'callback']
);


// Talento Humano v0.5.0
$router->get('/admin/tthh', [HumanResourcesController::class, 'index']);
$router->get('/admin/tthh/form', [HumanResourcesController::class, 'form']);
$router->post('/admin/tthh/save', [HumanResourcesController::class, 'save']);
$router->get('/admin/tthh/solicitudes', [HumanResourcesController::class, 'requests']);
$router->get('/admin/tthh/catalogos', [HumanResourcesController::class, 'catalogs']);
$router->post('/admin/tthh/catalogos/save', [HumanResourcesController::class, 'catalogSave']);

// v0.5.1 - TIC / Microsoft 365 provisioning
$router->get('/admin/tic', [\App\Controllers\Admin\TicProvisioningController::class, 'index']);
$router->get('/admin/tic/solicitud', [\App\Controllers\Admin\TicProvisioningController::class, 'show']);
$router->post('/admin/tic/usernames/validar', [\App\Controllers\Admin\TicProvisioningController::class, 'validateUsernames']);
$router->post('/admin/tic/usernames/seleccionar', [\App\Controllers\Admin\TicProvisioningController::class, 'selectUsername']);
$router->get('/admin/tic/licencias', [\App\Controllers\Admin\TicProvisioningController::class, 'licenses']);
$router->post('/admin/tic/licencias/save', [\App\Controllers\Admin\TicProvisioningController::class, 'licenseSave']);
$router->post('/admin/tic/provisionar', [\App\Controllers\Admin\TicProvisioningController::class, 'provision']);
$router->get('/admin/tic/cuentas', [\App\Controllers\Admin\TicProvisioningController::class, 'accounts']);
$router->get('/admin/tic/cuenta', [\App\Controllers\Admin\TicProvisioningController::class, 'account']);
$router->post('/admin/tic/cuenta/password-reset', [\App\Controllers\Admin\TicProvisioningController::class, 'resetPassword']);

// v0.6.0 - Admisiones y Estudiantes
$router->get('/admin/admisiones', [\App\Controllers\Admin\AdmissionsController::class, 'index']);
$router->get('/admin/admisiones/nueva', [\App\Controllers\Admin\AdmissionsController::class, 'form']);
$router->post('/admin/admisiones/save', [\App\Controllers\Admin\AdmissionsController::class, 'save']);
$router->get('/admin/admisiones/solicitud', [\App\Controllers\Admin\AdmissionsController::class, 'show']);
$router->post('/admin/admisiones/revisar', [\App\Controllers\Admin\AdmissionsController::class, 'review']);
$router->post('/admin/admisiones/aprobar', [\App\Controllers\Admin\AdmissionsController::class, 'approve']);
$router->post('/admin/admisiones/rechazar', [\App\Controllers\Admin\AdmissionsController::class, 'reject']);
$router->get('/admin/estudiantes', [\App\Controllers\Admin\AdmissionsController::class, 'students']);
$router->get('/admin/estudiantes/ver', [\App\Controllers\Admin\AdmissionsController::class, 'student']);
$router->post('/admin/estudiantes/contacto/save', [\App\Controllers\Admin\AdmissionsController::class, 'contactSave']);
$router->post('/admin/estudiantes/socio/save', [\App\Controllers\Admin\AdmissionsController::class, 'socioSave']);

// v0.6.1 - Catálogos académicos base
$router->get('/admin/academico/catalogos', [\App\Controllers\Admin\AcademicCatalogController::class, 'index']);
$router->get('/admin/academico/carreras/form', [\App\Controllers\Admin\AcademicCatalogController::class, 'careerForm']);
$router->post('/admin/academico/carreras/save', [\App\Controllers\Admin\AcademicCatalogController::class, 'careerSave']);
$router->get('/admin/academico/sedes/form', [\App\Controllers\Admin\AcademicCatalogController::class, 'campusForm']);
$router->post('/admin/academico/sedes/save', [\App\Controllers\Admin\AcademicCatalogController::class, 'campusSave']);
$router->get('/admin/academico/mallas/form', [\App\Controllers\Admin\AcademicCatalogController::class, 'curriculumForm']);
$router->post('/admin/academico/mallas/save', [\App\Controllers\Admin\AcademicCatalogController::class, 'curriculumSave']);
$router->post('/admin/academico/modalidades/save', [\App\Controllers\Admin\AcademicCatalogController::class, 'modalitySave']);

// v0.7.0 - Estructura y trayectoria académica
$router->get('/admin/academico/estructura', [\App\Controllers\Admin\AcademicTrajectoryController::class, 'index']);
$router->post('/admin/academico/cohortes/save', [\App\Controllers\Admin\AcademicTrajectoryController::class, 'cohortSave']);
$router->post('/admin/academico/asignaturas/save', [\App\Controllers\Admin\AcademicTrajectoryController::class, 'subjectSave']);
$router->get('/admin/academico/malla', [\App\Controllers\Admin\AcademicTrajectoryController::class, 'curriculum']);
$router->post('/admin/academico/malla/asignatura/save', [\App\Controllers\Admin\AcademicTrajectoryController::class, 'curriculumSubjectSave']);
$router->post('/admin/academico/malla/prerrequisito/save', [\App\Controllers\Admin\AcademicTrajectoryController::class, 'prerequisiteSave']);
$router->get('/admin/academico/trayectoria', [\App\Controllers\Admin\AcademicTrajectoryController::class, 'student']);
$router->post('/admin/academico/trayectoria/save', [\App\Controllers\Admin\AcademicTrajectoryController::class, 'trajectorySave']);
$router->get('/admin/academico/historial', [\App\Controllers\Admin\AcademicHistoryController::class, 'student']);

// v0.9.0 - Períodos y oferta académica
$router->get('/admin/academico/oferta', [\App\Controllers\Admin\AcademicOfferingController::class, 'index']);
$router->get('/admin/academico/periodos/form', [\App\Controllers\Admin\AcademicOfferingController::class, 'periodForm']);
$router->post('/admin/academico/periodos/save', [\App\Controllers\Admin\AcademicOfferingController::class, 'periodSave']);
$router->get('/admin/academico/oferta/form', [\App\Controllers\Admin\AcademicOfferingController::class, 'offerForm']);
$router->post('/admin/academico/oferta/save', [\App\Controllers\Admin\AcademicOfferingController::class, 'offerSave']);
$router->get('/admin/academico/oferta/ver', [\App\Controllers\Admin\AcademicOfferingController::class, 'show']);
$router->post('/admin/academico/oferta/seccion/save', [\App\Controllers\Admin\AcademicOfferingController::class, 'sectionSave']);


// v0.9.1 - Motor de matrícula y renovación
$router->get('/admin/academico/matriculas', [\App\Controllers\Admin\AcademicEnrollmentController::class, 'index']);
$router->get('/admin/academico/matriculas/estudiante', [\App\Controllers\Admin\AcademicEnrollmentController::class, 'student']);
$router->get('/admin/academico/matriculas/propuesta', [\App\Controllers\Admin\AcademicEnrollmentController::class, 'proposal']);
$router->post('/admin/academico/matriculas/crear', [\App\Controllers\Admin\AcademicEnrollmentController::class, 'create']);
$router->get('/admin/academico/matriculas/ver', [\App\Controllers\Admin\AcademicEnrollmentController::class, 'show']);
$router->post('/admin/academico/matriculas/confirmar', [\App\Controllers\Admin\AcademicEnrollmentController::class, 'confirm']);
$router->post('/admin/academico/matriculas/confirmar-masivo', [\App\Controllers\Admin\AcademicEnrollmentController::class, 'bulkConfirm']);

// v0.10.0 - Financiero: tarifas, órdenes, pagos y habilitación
$router->get('/admin/financiero', [\App\Controllers\Admin\FinanceController::class, 'index']);
$router->get('/admin/financiero/tarifas', [\App\Controllers\Admin\FinanceController::class, 'tariffs']);
$router->post('/admin/financiero/tarifas/save', [\App\Controllers\Admin\FinanceController::class, 'tariffSave']);
// v0.10.6 - Calendario de pagos por PAO
$router->post('/admin/financiero/calendario/save', [\App\Controllers\Admin\FinanceController::class, 'calendarSave']);

$router->post('/admin/financiero/orden/generar', [\App\Controllers\Admin\FinanceController::class, 'orderCreate']);
$router->get('/admin/financiero/orden', [\App\Controllers\Admin\FinanceController::class, 'order']);
$router->post('/admin/financiero/orden/anular', [\App\Controllers\Admin\FinanceController::class, 'orderAnnul']);
$router->post('/admin/financiero/pagos/registrar', [\App\Controllers\Admin\FinanceController::class, 'paymentRegister']);
$router->post('/admin/financiero/pagos/revisar', [\App\Controllers\Admin\FinanceController::class, 'paymentReview']);
$router->get('/admin/financiero/pagos/comprobante', [\App\Controllers\Admin\FinanceController::class, 'paymentProof']);

// v0.10.8 - Portal financiero del estudiante
$router->get('/estudiante/financiero', [\App\Controllers\Student\StudentFinanceController::class, 'index']);
$router->post('/estudiante/financiero/comprobante', [\App\Controllers\Student\StudentFinanceController::class, 'register']);
$router->get('/estudiante/financiero/comprobante', [\App\Controllers\Student\StudentFinanceController::class, 'proof']);

// v0.11.0 - Diagnóstico Moodle (solo lectura, protegido por TIC)
$router->get('/admin/tic/moodle', [\App\Controllers\Admin\MoodleIntegrationController::class, 'index']);

// v0.11.3 - Vinculación confirmada por TIC; no escribe en Moodle.
$router->post('/admin/tic/moodle/vincular', [\App\Controllers\Admin\MoodleIntegrationController::class, 'link']);
$router->post('/admin/tic/moodle/sincronizar-categorias', [\App\Controllers\Admin\MoodleIntegrationController::class, 'syncCategories']);
$router->post('/admin/tic/moodle/crear-curso', [\App\Controllers\Admin\MoodleIntegrationController::class, 'createCourse']);

// Orion v0.11.10 — panel académico independiente de cupos
$router->get('/admin/academico/cupos', [\App\Controllers\Admin\CapacityRequestController::class, 'academicIndex']);
// Orion v0.11.9 — cupos adicionales
$router->get('/admin/academico/cupos/solicitar', [\App\Controllers\Admin\CapacityRequestController::class, 'form']);
$router->post('/admin/academico/cupos/solicitar', [\App\Controllers\Admin\CapacityRequestController::class, 'request']);
$router->get('/admin/tic/cupos', [\App\Controllers\Admin\CapacityRequestController::class, 'index']);
$router->post('/admin/tic/cupos/resolver', [\App\Controllers\Admin\CapacityRequestController::class, 'resolve']);
