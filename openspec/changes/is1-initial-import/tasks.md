# Tasks

## 1. El esqueleto y la entrada

- [x] 1.1 Completar el esqueleto según las decisiones 1, 2, 6 y 8. `LICENSE.md` (MIT) y el `.gitignore` (`software/`, `tmp/`, `.claude/`, `.opencode/` y `.vscode/`) ya vienen del commit inicial. Añadir:
  - `VERSION` con `0.1.0`;
  - `versions.sh` con todas las versiones de la decisión 3;
  - `scripts/check-version.sh`;
  - un CHANGELOG con la sección `[Unreleased]`.

  Verificar que `scripts/check-version.sh develop/v0.1.0` pasa y que con `develop/v0.2.0` falla nombrando las dos versiones.
- [x] 1.2 Crear `lib/common.sh` (decisión 5) y `install.sh` (decisión 3) con la tabla de componentes y dependencias, `--list` y `--dry-run`. Verificar, todavía sin componentes:
  - que `./install.sh --dry-run qt-static` muestra `gcc qt-static`, y `./install.sh --dry-run protobuf-wasm buf` muestra `qt qt-wasm protobuf-wasm buf`;
  - que un nombre desconocido falla sin hacer nada y lista los válidos;
  - que `--list` muestra los once componentes con su versión.
- [x] 1.3 Escribir AGENTS.md (decisión 11) y la estructura del README y de `docs/toolchain.md`, con las convenciones comunes: el directorio de instalación, el sello, las descargas comprobadas, el versionado, y que el repositorio no se mueve ni se limpia con `git clean -xdf`. Verificar que coincide con `install.sh`, `lib/common.sh` y `versions.sh`.

## 2. Los compiladores

- [x] 2.1 Crear `components/gcc.sh` a partir de `build-gcc.sh` de guita, con el sello y el caso del enlace simbólico (decisión 4). Instalarlo en `software/` y medir el tiempo. Verificar:
  - que `software/gcc-16.2.0/bin/g++ -dumpfullversion` da 16.2.0, y que compila un programa en C++26 con `-freflection`;
  - que `-v` muestra las mismas opciones de configuración que el `~/software/gcc-16.2.0` de hoy;
  - que con un `SOFTWARE_DIR` en `tmp/` donde `gcc-16.2.0` es un enlace a `~/software/gcc-16.2.0`, el componente lo da por instalado sin compilar nada.
- [x] 2.2 Crear `components/gcc-mingw.sh` a partir de `build-gcc-mingw.sh`, con el sello en lugar de la marca `libstdc++.a`, y con `--check` y `--check <ejecutable>`. Instalarlo. Verificar:
  - que termina con la comprobación pasada con Wine;
  - que `--check` sobre un ejecutable que importa una DLL de prueba llamada `libstdc++-6.dll` falla y la nombra;
  - que con el keyring de GNU en lugar del de mingw-w64, en un `SOFTWARE_DIR` de `tmp/`, falla antes de compilar nombrando el tarball (escenario «Firma de otra clave»).
- [x] 2.3 Documentar los dos compiladores en `docs/toolchain.md` (configuración, por qué, tiempo y disco medidos) y en el README. Verificar que coincide con los scripts.

## 3. Los kits de Qt

- [x] 3.1 Crear `components/qt.sh` y `components/qt-wasm.sh` a partir de `setup-qt.sh`, con aqt en `software/aqt-venv`, el sello y la comprobación de módulos. Instalarlos. Verificar:
  - que los dos kits tienen `Qt6TaskTree` y `Qt6WebSockets`;
  - que el emsdk instalado es el `QT_EMCC_RECOMMENDED_VERSION` del kit WebAssembly;
  - que al quitar `lib/cmake/Qt6WebSockets` del kit de escritorio, `./install.sh qt` lo reinstala completo.
- [x] 3.2 Crear `components/qt-static.sh` a partir de la parte de Qt de `build-static-deps.sh`, con las mismas opciones y módulos. Instalarlo y medir el tiempo. Verificar:
  - que tiene los seis módulos y ninguna `libQt6*.so`;
  - que `bin/qtpaths6 --qt-query QT_VERSION` da 6.12.0 desde una shell sin `LD_LIBRARY_PATH`;
  - que con un kit al que le falta un módulo, en un `SOFTWARE_DIR` de `tmp/`, el componente comprueba las descargas, lo borra y empieza a compilar qtbase. Se interrumpe ahí y se borra ese directorio.
- [x] 3.3 Documentar los kits en `docs/toolchain.md` y en el README: los módulos como unión de lo que usan los proyectos, las opciones del estático, los requisitos del sistema, el tiempo y el disco. Verificar que coincide con los scripts.

## 4. Las librerías

- [x] 4.1 Crear `components/libpqxx.sh`, `cpp-httplib.sh`, `protobuf.sh`, `protobuf-wasm.sh` y `buf.sh` a partir de `build-deps.sh`, con el sello. Instalarlos. Verificar:
  - que el `protoc` instalado informa de 36.2 desde una shell sin `LD_LIBRARY_PATH`;
  - que `protobuf-36.2-wasm` no tiene `protoc`;
  - que `buf --version` da 1.74.0;
  - que una segunda ejecución de `./install.sh` con los cinco termina sin compilar nada.
- [x] 4.2 Crear `components/libpq-static.sh` a partir de la parte de libpq de `build-static-deps.sh`. Instalarlo. Verificar que tiene `libpq.a`, `libpgcommon_shlib.a` y `libpgport_shlib.a`, ninguna `libpq.so*`, y que `pg_config --version` da 18.6.
- [x] 4.3 Comprobar los escenarios de `instalacion` con componentes rápidos, en un `SOFTWARE_DIR` de `tmp/` con el GCC enlazado:
  - con el tarball de PostgreSQL truncado, `libpq-static` falla antes de compilar, nombra el fichero y no crea su prefijo;
  - `libpqxx` interrumpido durante su compilación no queda sellado, y la siguiente ejecución lo instala desde el principio. Se probó con `libpqxx` y no con `cpp-httplib`, que solo instala cabeceras y termina en un par de segundos;
  - un prefijo de `cpp-httplib` sin sello y con un fichero de sobra se da por no instalado, se borra y se instala de nuevo, sin ese fichero;
  - el directorio `software/` del repositorio no aparece en `git status`.

  Después se borra el directorio.
- [x] 4.4 Documentar las librerías en `docs/toolchain.md` y en el README. Verificar que coincide con los scripts.

## 5. La integración

- [ ] 5.1 Comparar cada prefijo de `software/` con el de `~/software`: las versiones que informan y la lista de ficheros. Anotar en el diseño (decisión 7) cualquier diferencia y su causa.
- [ ] 5.2 Probar guita de extremo a extremo con un `CMakeUserPresets.json` local, sin tocar ningún fichero versionado de guita, con presets que apuntan a `${sourceDir}/../toolchain-cpp/software`. Verificar:
  - el build nativo con `ctest` completo;
  - el build WebAssembly;
  - el cliente estático, con `scripts/build-static.sh --check` sobre el ejecutable.

  Después se borra ese fichero.
- [ ] 5.3 Crear `.github/workflows/ci.yml` según la decisión 10. Verificar sus pasos en local:
  - las comprobaciones rápidas, en esta máquina;
  - la instalación de prueba, en un contenedor `gcc:16.2.0-trixie` con Docker.

  Verificar también que un error de sintaxis puesto a propósito en un script hace fallar la comprobación nombrándolo.
- [ ] 5.4 Completar el README con el uso desde un proyecto (decisión 9): ejemplo de preset, de script y de CI. Completar el CHANGELOG. Verificar que los comandos documentados funcionan tal cual.
- [ ] 5.5 El usuario revisa el repositorio y da el visto bueno.
