# qt Specification

## Purpose

Los kits de Qt de los proyectos: los oficiales de escritorio y de WebAssembly, con su Emscripten, y los estáticos de Linux y de Windows compartidos por todos.

## Requirements

### Requirement: Kits de escritorio y WebAssembly
El componente del kit de escritorio SHALL instalar el kit oficial de Qt para Linux x86_64, en la versión del fichero de versiones. Lleva los módulos adicionales que necesitan los proyectos, una sola lista que es la unión de todos. El componente del kit WebAssembly SHALL instalar el kit `wasm_singlethread` de la misma versión, con los mismos módulos, junto con:
- la versión de Emscripten que recomienda ese kit;
- el Python que necesita Emscripten.

Un kit al que le falte un módulo de la lista MUST volver a instalarse.

#### Scenario: Kit de escritorio
- **WHEN** se instala el componente del kit de escritorio
- **THEN** el kit queda con todos los módulos de la lista

#### Scenario: Un módulo que falta
- **WHEN** el kit instalado no tiene uno de los módulos de la lista
- **THEN** el componente vuelve a instalar el kit con todos ellos

#### Scenario: Emscripten del kit
- **WHEN** se instala el componente del kit WebAssembly
- **THEN** la versión de Emscripten instalada es la que recomienda el kit (`QT_EMCC_RECOMMENDED_VERSION`)

### Requirement: Qt estático de Linux compartido
El componente del Qt estático SHALL compilar con el compilador nativo un Qt estático de la versión del kit de escritorio. Lleva los módulos que es la unión de lo que usan los proyectos: qtbase con Qt SQL y SQLite, qtshadertools, qtsvg, qtdeclarative, qtwebsockets y las herramientas de Linguist. Solo X11, y cada funcionalidad que dependería de los paquetes `-devel` instalados queda fijada. Un kit al que le falta un módulo de la lista MUST borrarse y compilarse entero, después de comprobar las descargas. Las herramientas del kit que se ejecutan al compilar un proyecto MUST arrancar sin `LD_LIBRARY_PATH`.

#### Scenario: Instalación
- **WHEN** se instala el componente
- **THEN** el kit estático queda con los módulos de la lista, sin ninguna librería compartida de Qt

#### Scenario: Un módulo que falta
- **WHEN** el kit estático instalado no tiene uno de los módulos de la lista
- **THEN** el componente lo borra y lo compila entero con todos ellos

### Requirement: Qt estático para Windows compartido
El componente del Qt para Windows SHALL compilar con el compilador cruzado un Qt estático para Windows de 64 bits, de la versión del kit de escritorio, que hace de host del build. Lleva la unión de los módulos que usan los proyectos: qtbase con Qt SQL y SQLite, qtshadertools, qtsvg, qtdeclarative y qtwebsockets. Las herramientas de Linguist vienen del host. Su TLS MUST ser el de Windows, sin depender de OpenSSL. Las librerías de terceros que necesita MUST ser las copias de Qt, porque en Windows no hay librerías del sistema. Un kit al que le falta un módulo de la lista MUST borrarse y compilarse entero, después de comprobar las descargas.

#### Scenario: Instalación
- **WHEN** se instala el componente con el compilador cruzado y el kit de escritorio instalados
- **THEN** el kit queda con los módulos de la lista, el plugin de la plataforma de Windows y el de TLS de Windows, sin ninguna DLL

#### Scenario: Una aplicación Qt para Windows
- **WHEN** se compila con el kit una aplicación Qt Quick mínima y se listan las DLLs que importa
- **THEN** solo importa DLLs de Windows, y arranca en Windows 10 u 11 o en Wine
