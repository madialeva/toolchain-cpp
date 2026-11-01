# Proposal

## Why

Los proyectos C++ del mantenedor (guita, gambasse y los que vengan) trabajan con el mismo toolchain: GCC 16.2 compilado desde las fuentes, los kits de Qt 6.12, un Qt estático compartido, las librerías del backend y un compilador cruzado para Windows. Cada proyecto lo construye con copias de los mismos scripts:
- gambasse tiene su propio `build-gcc.sh`, con el mismo código que el de guita, su `setup-qt.sh` y un `build-static-deps.sh` con el bloque de Qt copiado a mano y vigilado con `diff`;
- todo se instala en `~/software`, un directorio de la máquina que usan todos los proyectos y que no es de ninguno;
- cambiar una versión toca varios scripts en varios repositorios. La regla de guita para una versión nueva de GCC nombra cinco scripts, dos presets y el CI.

Un repositorio propio para el toolchain lo desacopla de los proyectos. Cada proyecto se queda con sus presets y sus scripts de build, y uno nuevo empieza sin copiar nada. guita lo dejó previsto en su issue #26 («si se suma un tercer proyecto»), y ya hay uno en camino. Es el issue #1.

## What Changes

- **Un repositorio nuevo, `toolchain-cpp`**, público y con licencia MIT, con los scripts de guita que construyen el toolchain:
  - organizados en **componentes que se instalan por nombre** (`./install.sh gcc qt qt-static ...`), con sus dependencias resueltas;
  - **un único fichero con todas las versiones**;
  - **las funciones comunes en un solo sitio**: descargas comprobadas y requisitos previos.
- **Todo lo compilado, con sus fuentes, dentro del repositorio**, en `software/` (ignorado por git). Tiene la misma estructura que el `~/software` de hoy, y `SOFTWARE_DIR` lo cambia de sitio.
- **Los proyectos lo usan clonado junto a ellos** (`../toolchain-cpp`). El README documenta cómo referenciarlo desde los presets, los scripts y el CI de un proyecto.
- **Versionado propio:** un fichero `VERSION`, ramas `develop/vX.Y.Z`, tags y un CHANGELOG. Cada proyecto fija el tag que usa.
- **Un CI ligero:** comprueba la versión contra la rama y la sintaxis de los scripts, y hace una instalación de prueba de componentes rápidos.
- **Documentación:**
  - un README;
  - un AGENTS.md con las convenciones heredadas de guita;
  - `docs/toolchain.md`, la referencia técnica que hoy está en el §8 de la arquitectura de guita.
- **Ningún cambio en lo que se compila:** cada componente produce lo mismo que el script de guita del que sale.

## Capabilities

### New Capabilities

- `instalacion`: cómo se instalan los componentes:
  - por nombre, con sus dependencias;
  - dónde se instalan;
  - sin root;
  - sin repetir lo ya instalado;
  - con las descargas comprobadas antes de compilar nada.
- `compilador-nativo`: GCC 16.2 compilado desde las fuentes de GNU, el compilador nativo de los proyectos.
- `compilador-cruzado`: el GCC 16.2 cruzado para Windows de 64 bits y su comprobación.
- `qt`: los kits de Qt 6.12 (escritorio, WebAssembly con emsdk, y el estático de Linux compartido por los proyectos).
- `librerias`: libpqxx, cpp-httplib, protobuf con abseil (nativo y WebAssembly), buf y libpq estática.
- `integracion-continua`: el CI del propio repositorio.

### Modified Capabilities

Ninguna: es un repositorio nuevo.

## Impact

- **GitHub:** el repositorio `madialeva/toolchain-cpp`.
- **guita y gambasse:** nada en este cambio, y hasta entonces siguen con `~/software`. Cada uno pasa a usarlo en un cambio propio:
  - quitar sus scripts del toolchain;
  - apuntar sus presets y su CI a `../toolchain-cpp`;
  - actualizar su documentación, y quitar de sus specs los requisitos que pasan aquí.
- **#29 de guita** (el cliente para Windows): sus dependencias para Windows y el fichero de toolchain de CMake se harán en este repositorio, en un cambio posterior a este.
- **Entorno local:**
  - recompilar todo en `software/`: unas 2 o 3 horas de máquina, sobre todo el bootstrap de GCC y el Qt estático;
  - lo que los proyectos usan de `~/software` se borra cuando guita y gambasse hayan pasado al nuevo repositorio.
- **Dependencias:** ninguna nueva. Son las mismas versiones con las mismas opciones.
