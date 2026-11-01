# Design

## Context

La motivación está en proposal.md y los requisitos en las specs de este cambio. Lo que condiciona el diseño:

- **Lo que se importa.** Son los scripts de guita que construyen el toolchain, en su rama `develop/v0.1.0`:

  | Script de guita | Qué instala en `~/software` |
  |---|---|
  | `build-gcc.sh` | GCC 16.2.0 (`gcc-16.2.0`), con la configuración de la imagen `gcc:16.2.0-trixie` del CI |
  | `build-gcc-mingw.sh` | el GCC 16.2.0 cruzado para Windows (`gcc-16.2.0-mingw`), con binutils 2.47 y mingw-w64 14.0.0, y su comprobación con Wine |
  | `setup-qt.sh` | con aqt, los kits de Qt 6.12.0 de escritorio y `wasm_singlethread` con qttasktree y qtwebsockets, emsdk 5.0.5, y Python 3.12 con uv; `--desktop-only` instala solo el kit de escritorio |
  | `build-deps.sh` | libpqxx 8.0.2, cpp-httplib 0.61.0, protobuf 36.2 con abseil (nativo y para WebAssembly) y buf 1.74.0 |
  | `build-static-deps.sh` | el Qt 6.12.0 estático de Linux, compartido con gambasse mediante un bloque idéntico en los dos repositorios, y la libpq 18.6 estática |

  Las copias de gambasse son subconjuntos de estas:
  - `build-gcc.sh` es el mismo código, con otros comentarios;
  - `setup-qt.sh` solo instala el kit de escritorio, sin módulos adicionales;
  - `build-static-deps.sh` lleva el mismo bloque de Qt y no lleva libpq.
- **Las convenciones de esos scripts:**
  - sin root;
  - versiones y opciones fijadas, independientes de los paquetes `-devel` instalados;
  - fuentes en `$SOFTWARE_DIR/src`;
  - descargas comprobadas antes de compilar o borrar nada;
  - lo ya instalado no se recompila. La excepción es `build-deps.sh`, que vuelve a compilar sus librerías en cada ejecución; el CI de guita lo evita con su caché;
  - los ejecutables compilados con el GCC 16 (`protoc` y las herramientas del Qt estático) llevan un run path a su `libstdc++`.
- **Cómo los usan los proyectos:**
  - guita y gambasse apuntan a `~/software/...` desde sus presets (`$env{HOME}/software/gcc-16.2.0/bin/g++`, ...) y sus scripts (`SOFTWARE_DIR`);
  - en el CI de guita, `~/software/gcc-16.2.0` es un enlace al GCC de la imagen, y la caché del toolchain va por el hash de `setup-qt.sh` y `build-deps.sh`.
- **Decisiones del usuario:**
  - el repositorio se llama `toolchain-cpp`, es público y tiene licencia MIT;
  - lo compilado va dentro del repositorio, en un directorio ignorado;
  - los proyectos lo encuentran clonado a su lado;
  - el cambio se hace con OpenSpec.

## Goals / Non-Goals

**Goals:**
- Instalar con un solo repositorio todo lo que hoy instalan los scripts de guita, con el mismo resultado.
- Elegir qué se instala por componentes, para que cada proyecto instale solo lo suyo.
- Una sola fuente para las versiones y para las funciones comunes.
- Un contrato claro con los proyectos: la estructura del directorio de instalación y la versión del repositorio.
- Dejarlo listo para que guita y gambasse lo adopten, y para las dependencias de Windows de #29.

**Non-Goals:**
- **Que guita y gambasse lo usen.** Cada uno lo hará en un cambio propio, que quitará sus scripts del toolchain y los requisitos de sus specs que pasan aquí.
- **Las dependencias para Windows de #29** (Qt, OpenSSL, libpq, protobuf, libpqxx y cpp-httplib para Windows, y el fichero de toolchain de CMake). Irán en el siguiente cambio de este repositorio.
- **Borrar `~/software`.** Lo siguen usando guita y gambasse hasta que pasen.
- **Compilar GCC o Qt en el CI.** Tardan de media hora a una hora; el CI solo instala componentes rápidos.
- **shellcheck en el CI.** Los scripts nunca se han pasado por shellcheck, y arreglar lo que salga cambiaría el código importado.
- **Otros sistemas.** Lo probado es Oracle Linux 9 en local y Debian trixie (la imagen de GCC) en el CI.
- **Un gestor de paquetes (Conan, vcpkg) o binarios precompilados del toolchain.** Se siguen compilando en cada máquina scripts pequeños con cada versión y opción fijadas.

## Decisions

### 1. Estructura del repositorio

```text
install.sh            la entrada: instala componentes por nombre (decisión 3)
versions.sh           todas las versiones, una sola vez
components/           un script por componente: gcc.sh, qt-static.sh, ...
lib/common.sh         funciones comunes de los componentes (decisión 5)
scripts/              utilidades del repositorio: check-version.sh (decisión 8)
docs/toolchain.md     la referencia técnica
software/             lo descargado, compilado e instalado (ignorado por git, decisión 2)
openspec/  .github/  README.md  AGENTS.md  CHANGELOG.md  LICENSE.md  VERSION
```

Cada script de `components/` se puede ejecutar solo: comprueba sus requisitos y falla nombrando el componente que falta. `install.sh` resuelve además las dependencias.

### 2. Todo en `software/`, con la estructura de `~/software`

- **Por defecto** se instala en `software/`, dentro del repositorio e ignorado por git. `SOFTWARE_DIR` lo cambia de sitio, con el mismo nombre de variable que los scripts de hoy. Dentro, los mismos prefijos que `~/software` (`gcc-16.2.0`, `Qt/6.12.0/gcc_64`, `Qt/6.12.0-static`, `protobuf-36.2`, ...) y las fuentes en `src/`.
- **Para un proyecto, cambiar de sitio es solo cambiar la base de las rutas.**
- **Lo único fuera de `software/`** es el Python de uv, en la ubicación estándar de uv, como hoy.

Consecuencias, que se documentan:
- Lo compilado lleva rutas absolutas: los run paths al `libstdc++` de GCC 16 y los ficheros `.la`, entre otras. Mover el repositorio después de compilar obliga a recompilar, igual que mover `~/software`.
- Un `git clean -xdf` en el repositorio borraría todo lo compilado.

### 3. Componentes por nombre: `install.sh`

| Componente | Qué instala | Prefijo en `software/` | Necesita |
|---|---|---|---|
| `gcc` | GCC 16.2.0, C y C++ | `gcc-16.2.0` | el compilador de C++ del sistema |
| `gcc-mingw` | GCC 16.2.0 cruzado para Windows, binutils 2.47 y mingw-w64 14.0.0 | `gcc-16.2.0-mingw` | `gcc` |
| `qt` | kit de escritorio de Qt 6.12.0, con qttasktree y qtwebsockets | `Qt/6.12.0/gcc_64` | python3 con venv |
| `qt-wasm` | kit `wasm_singlethread` de Qt 6.12.0, emsdk 5.0.5 y Python 3.12 (uv) | `Qt/6.12.0/wasm_singlethread`, `emsdk` | `qt` |
| `qt-static` | Qt 6.12.0 estático de Linux | `Qt/6.12.0-static` | `gcc` |
| `libpq-static` | libpq de PostgreSQL 18.6, estática | `libpq-18.6-static` | `gcc` |
| `libpqxx` | libpqxx 8.0.2 | `libpqxx-8.0.2` | `gcc` |
| `cpp-httplib` | cpp-httplib 0.61.0 | `cpp-httplib-0.61.0` | `gcc` |
| `protobuf` | protobuf 36.2 con abseil y `protoc` | `protobuf-36.2` | `gcc` |
| `protobuf-wasm` | protobuf 36.2 con abseil para WebAssembly | `protobuf-36.2-wasm` | `qt-wasm` (por emsdk) |
| `buf` | buf 1.74.0 | `buf-1.74.0` | nada |

- `./install.sh <componente>...` añade las dependencias que falten y los instala en el orden de la tabla.
- `./install.sh --dry-run <componente>...` muestra ese plan sin hacer nada.
- `./install.sh --list` muestra cada componente con su versión y si está instalado.
- Un nombre desconocido falla antes de instalar nada.

La tabla de dependencias y el orden viven en `install.sh`. Un componente nuevo es un script en `components/` más su fila.

Correspondencia con los scripts de hoy:
- `setup-qt.sh --desktop-only` es `qt`, y `setup-qt.sh` es `qt qt-wasm`;
- `build-deps.sh` es `libpqxx cpp-httplib protobuf protobuf-wasm buf`;
- `build-static-deps.sh` es `qt-static libpq-static`.

Diferencias de comportamiento:
- **protobuf para WebAssembly.** Sin emsdk, `build-deps.sh` se lo salta con un aviso. Como componente, `protobuf-wasm` depende de `qt-wasm` y lo instala.
- **Librerías del backend.** libpqxx, cpp-httplib y protobuf ya no se recompilan en cada ejecución (decisión 4).

### 4. Marca de instalación: un sello al final

Cada componente escribe un sello, `.toolchain-cpp-installed`, en cada prefijo que instala, como último paso.

- **Con el sello,** el prefijo está instalado y no se toca.
- **Sin el sello** (un prefijo de una instalación que no terminó), el componente lo borra después de comprobar las descargas, y lo instala de nuevo.
- **Los kits de Qt** comprueban además su lista de módulos: si falta alguno, se reinstalan (los de aqt) o se compilan enteros (el estático), como hoy.
- **La excepción es `gcc`:** un prefijo que es un enlace simbólico a un GCC de la misma versión se da por instalado sin sello. Es el GCC de la imagen oficial en el CI de los proyectos.

Sustituye las marcas propias de cada script (el `libstdc++.a` del compilador cruzado, el `bin/g++` del nativo, ...). Todos los componentes funcionan igual, y una instalación interrumpida nunca pasa por completa.

### 5. Funciones comunes en `lib/common.sh`

Cada script de hoy repite sus funciones. Se reúnen, con el comportamiento de los scripts actuales:
- **rutas:** `SOFTWARE_DIR`, `SRC` y la raíz del repositorio;
- **requisitos:** que un componente esté instalado, con un mensaje que lo nombra y dice cómo instalarlo;
- **el sello** de la decisión 4;
- **descargas comprobadas:**
  - con la SHA-256 que publica el servidor (`<url>.sha256`): Qt y PostgreSQL;
  - con firma y un keyring publicado: el de GNU para GCC y binutils;
  - con firma y la clave fijada por su huella, descargada una vez de keyserver.ubuntu.com y exigida en el `VALIDSIG`: mingw-w64, y en el siguiente cambio OpenSSL;
  - con las sumas de su release: buf;
  - clonando de git la etiqueta de la versión: libpqxx, cpp-httplib y protobuf;
- **el compilador nativo** para los componentes que lo usan, con el run path a su `libstdc++`.

### 6. Una sola fuente para las versiones: `versions.sh`

Todas las versiones de la tabla, cada una sobrescribible por el entorno como hoy (`GCC_VERSION=... ./install.sh gcc`). Los componentes y `install.sh --list` las leen de ahí.

Las listas de módulos de Qt y las opciones de configuración se quedan en el script de su componente, junto al código que las usa. Son la unión de lo que necesitan los proyectos; un módulo nuevo se añade ahí, en un cambio de este repositorio.

### 7. Lo que se importa no cambia

Cada componente compila lo mismo que el script del que sale: las mismas versiones, opciones, prefijos y comprobaciones. Lo único que cambia es la estructura de las decisiones 1 a 6. El bloque de Qt estático deja de estar repetido; cuando gambasse lo adopte, también desaparecerá su copia.

Para comprobarlo, se compila todo desde cero en `software/` y se compara con `~/software`: las versiones que informan y la lista de ficheros de cada prefijo.

### 8. Versionado y flujo de trabajo

- **`VERSION`** es la versión del repositorio, con el mismo flujo de GitHub que guita: rama `develop/vX.Y.Z`, `release/vX.Y.Z` y tag `vX.Y.Z`. `scripts/check-version.sh <rama>` la compara con la rama.
- **SemVer, en función de lo que tiene que hacer un proyecto para subir de versión:**
  - **MAJOR** si tiene que cambiar sus presets o scripts: cambia el nombre de un componente o de un prefijo, como con una versión nueva de GCC o de Qt;
  - **MINOR** si hay componentes u opciones nuevas sin tocar lo existente;
  - **PATCH** si se corrige un script sin cambiar lo que instala.

  Antes de 1.0.0, como en guita, cualquier cosa puede cambiar.
- **Primera versión:** al terminar este cambio, el usuario publica `v0.1.0`, y los proyectos la fijan al adoptarlo.

### 9. Cómo lo usan los proyectos

Se documenta en el README y en `docs/toolchain.md`, y cada proyecto lo adopta en su cambio:
- **Ubicación:** `toolchain-cpp` clonado junto al proyecto (`~/src/toolchain-cpp` al lado de `~/src/guita`).
- **Presets:** las rutas son relativas al proyecto, sin variables de entorno: `${sourceDir}/../toolchain-cpp/software/gcc-16.2.0/bin/g++`. Quien lo tenga en otro sitio las cambia en su `CMakeUserPresets.json`.
- **Scripts:** una variable con el directorio de instalación, por defecto `../toolchain-cpp/software` relativo al proyecto.
- **CI:**
  - dos checkouts, uno al lado del otro, el de `toolchain-cpp` en el tag que fija el proyecto;
  - `software/gcc-16.2.0` como enlace al GCC de la imagen (decisión 4);
  - `./install.sh` con los componentes del proyecto;
  - la caché de `software/`, por ese tag.
- **Componentes:** cada proyecto lista los suyos en su documentación y en su CI.

### 10. El CI del repositorio

`.github/workflows/ci.yml`, en pushes a `develop/**` y `release/**` y en los pull requests hacia ellas:
- **comprobaciones rápidas**, en `ubuntu-latest`: `scripts/check-version.sh` y `bash -n` de cada script;
- **una instalación de prueba**, en el contenedor `gcc:16.2.0-trixie`:
  - comprueba que el GCC de la imagen es el de `versions.sh`;
  - lo enlaza como `software/gcc-16.2.0`;
  - instala `cpp-httplib` y `buf`. Ejercitan `install.sh`, las dependencias, el sello, las descargas comprobadas y el uso del compilador nativo, en un par de minutos.

### 11. Documentación

- **README:** qué es, los componentes, cómo instalarlos, cómo usarlo desde un proyecto, y los requisitos del sistema.
- **AGENTS.md:** las convenciones de guita que aplican aquí, adaptadas a este repositorio: los principios de las decisiones 2 a 8, OpenSpec, idiomas, preferencias de trabajo y el flujo de GitHub.
- **`docs/toolchain.md`:** la referencia técnica de cada componente, con sus opciones y por qué, el tiempo y el disco medidos, y el uso desde los proyectos. Se trae del §8 de la arquitectura de guita y de los diseños de sus cambios del toolchain (#16, #20, #26 y #28).
- **CHANGELOG:** Keep a Changelog, con la versión 0.1.0.

## Risks / Trade-offs

- [La importación cambia sin querer lo que se compila] → La comparación de la decisión 7 con `~/software`, y una prueba de guita de extremo a extremo con el nuevo directorio: build nativo con sus pruebas, WebAssembly y estático, con un `CMakeUserPresets.json` local que apunta a `../toolchain-cpp`.
- [Recompilar todo lleva horas] → Es una vez. Además demuestra que el repositorio reproduce el toolchain desde cero.
- [La convención del clon al lado no encaja en algún entorno] → Las rutas de un proyecto se cambian en su `CMakeUserPresets.json`, y `SOFTWARE_DIR` mueve la instalación.
- [Un `git clean -xdf` borra lo compilado, y el directorio no se puede mover] → Se documenta en el README y en AGENTS.md.
- [Dos sitios con el toolchain mientras guita y gambasse no pasan] → No se pisan: son directorios distintos. `~/software` se borra cuando los dos hayan pasado.

## Migration Plan

1. Este cambio crea el repositorio y compila todo en su `software/`.
2. El usuario publica `v0.1.0`.
3. guita pasa a usarlo (issue y cambio propios, que incluyen su CI), y después gambasse.
4. El usuario borra de `~/software` lo que dejó de usarse.

Deshacerlo antes del paso 3 es borrar el repositorio: guita y gambasse siguen con `~/software`.
