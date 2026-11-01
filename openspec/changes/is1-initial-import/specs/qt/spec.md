# Spec Delta

## ADDED Requirements

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
