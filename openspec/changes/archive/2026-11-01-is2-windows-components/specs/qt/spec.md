# Spec Delta

## ADDED Requirements

### Requirement: Qt estático para Windows compartido
El componente del Qt para Windows SHALL compilar con el compilador cruzado un Qt estático para Windows de 64 bits, de la versión del kit de escritorio, que hace de host del build. Lleva la unión de los módulos que usan los proyectos: qtbase con Qt SQL y SQLite, qtshadertools, qtsvg, qtdeclarative y qtwebsockets. Las herramientas de Linguist vienen del host. Su TLS MUST ser el de Windows, sin depender de OpenSSL. Las librerías de terceros que necesita MUST ser las copias de Qt, porque en Windows no hay librerías del sistema. Un kit al que le falta un módulo de la lista MUST borrarse y compilarse entero, después de comprobar las descargas.

#### Scenario: Instalación
- **WHEN** se instala el componente con el compilador cruzado y el kit de escritorio instalados
- **THEN** el kit queda con los módulos de la lista, el plugin de la plataforma de Windows y el de TLS de Windows, sin ninguna DLL

#### Scenario: Una aplicación Qt para Windows
- **WHEN** se compila con el kit una aplicación Qt Quick mínima y se listan las DLLs que importa
- **THEN** solo importa DLLs de Windows, y arranca en Windows 10 u 11 o en Wine
