# Design

## Context

- **El compilador cruzado (`gcc-mingw`)** está en `software/gcc-16.2.0-mingw`: GCC 16.2.0, binutils 2.47 y mingw-w64 14.0.0, con UCRT, Windows 10, hilos POSIX, TLS nativo y solo el runtime estático. El prefijo es el sysroot.
  - Su comprobación pasó con Wine 10.6 y en un Windows real.
  - En Windows, `std::print` necesita `-lstdc++exp`.
  - Oracle Linux 9 trae su propio `mingw64-gcc` 14.2.1 en `/usr/bin`, con enlaces de ccache delante en el PATH. Hay que usar el compilador del repositorio por su ruta, nunca por su nombre.
- **Qt 6.12.0 con MinGW desde Linux es viable.**
  - MXE tiene la receta de `qt6-qtbase` 6.12.0 para `x86_64-w64-mingw32`, estática y compartida. Configura con un fichero de toolchain de CMake, `QT_HOST_PATH` (un Qt nativo de la misma versión, con las herramientas del host: moc, rcc, qmlcachegen, qsb, ...) y `QT_QMAKE_TARGET_MKSPEC=win32-g++`.
  - Sus tres parches tocan la documentación, la detección de OpenSSL y freetype del sistema, nada de lo que se usa aquí.
  - Los demás módulos se configuran con el `qt-configure-module` del prefijo instalado, como en `qt-static`.
- **El kit de escritorio (`qt`)** tiene las herramientas de host de qtbase, qtdeclarative y Linguist. Le falta qtshadertools, y con él `qsb`, que el build cruzado de qtshadertools y qtdeclarative necesita en el host. aqt lo ofrece como módulo del kit `linux_gcc_64` de 6.12.0.
- **qttools no hace falta en el kit de Windows.** El kit WebAssembly no trae `Qt6LinguistTools`, y el build lo resuelve desde `QT_HOST_PATH` (lo vio guita). En la ruta de `QT_HOST_PATH` no puede haber `..`.
- **El fichero de toolchain va encadenado.** El `lib/cmake/Qt6/qt.toolchain.cmake` de un kit cruzado encadena, por su ruta absoluta, el fichero de toolchain con el que se configuró Qt, así que ese fichero tiene que vivir en un sitio estable.
- **libpq en mingw.** El `make install` de PostgreSQL deja `libpq.dll` y una biblioteca de importación que se llama `libpq.a`, y no hay opción de `configure` para una libpq estática. El paquete `mingw-postgresql` de Fedora y los PKGBUILD de mingw la crean con `ar` sobre los objetos de `src/interfaces/libpq`.
- **OpenSSL 3.5.9** (2026-09-29) es la última de la rama 3.5, LTS hasta abril de 2030.
  - Se publica en GitHub con su `.asc`, firmado por una subclave de la clave de firma de OpenSSL, cuya huella principal es `B146 647E 45A7 B339 47AB 226B 2A2C 87D1 6169 2D40` (openssl-library.org/source).
  - `gpgv` lo verificó, y `VALIDSIG` da esa huella en su último campo, el criterio de `check_signature`.
  - Compila para Windows con su objetivo `mingw64` y un prefijo de compilador cruzado.
- **cpp-httplib** solo se usa en los proyectos para el servidor y el canal. Un cliente con el backend embebido no abre ningún puerto, así que la compresión (zlib) no hace falta en Windows.
- **Las respuestas a guita#29:** el Qt para Windows es un kit compartido con gambasse, y libpq lleva TLS con un OpenSSL estático.

## Goals / Non-Goals

**Goals:**
- Que un proyecto compile para Windows con CMake, con el fichero de toolchain y los componentes `-mingw`, sin nada más.
- Un kit de Qt para Windows para todos los proyectos.
- Componentes reproducibles y comprobados, con las convenciones de los demás: versiones fijadas, descargas comprobadas y sello.

**Non-Goals:**
- **El cliente de guita para Windows y su comprobación de DLLs.** Es guita#29.
- **Compilar estos componentes en el CI.** Tardan; el CI solo instala componentes rápidos.
- **Windows de 32 bits o ARM64, un Qt compartido para Windows, MSVC.**
- **zlib, Brotli y zstd** en cpp-httplib para Windows.
- **Probar `wss://` de extremo a extremo.** Se comprueba que el plugin de Schannel está en el kit.

## Decisions

### 1. El fichero de toolchain, con el compilador

`components/gcc-mingw.sh` escribe `toolchain.cmake` en su prefijo:
- `CMAKE_SYSTEM_NAME` `Windows` y `CMAKE_SYSTEM_PROCESSOR` `x86_64`;
- `gcc`, `g++`, `windres`, `ar` y `ranlib` del compilador, con rutas relativas al fichero (`CMAKE_CURRENT_LIST_DIR`);
- el sysroot del compilador en `CMAKE_FIND_ROOT_PATH`, que se añade a las raíces que pasa quien lo usa (las de sus dependencias), y la búsqueda solo dentro de esas raíces (`CMAKE_FIND_ROOT_PATH_MODE_{LIBRARY,INCLUDE,PACKAGE}` en `ONLY`, programas en `NEVER`).

Se escribe al final de la instalación y también, sin recompilar, cuando el compilador ya estaba instalado y le falta. El sello sigue siendo la marca del compilador; el fichero se rehace si falta, antes de que `component_main` decida.

Por qué con el compilador:
- Qt lo encadena por su ruta absoluta.
- Es la cara CMake del compilador: lo usan los componentes de esta decisión y los proyectos.

Alternativas descartadas:
- **Un fichero en el repositorio** (`cmake/`). Los kits quedarían atados a la ruta del clon, que tampoco se puede mover, pero mezclaría ficheros versionados con lo instalado.
- **Pasar las variables a cada build.** Qt las necesita en su `qt.toolchain.cmake`.

### 2. qtshadertools en los kits de aqt

`lib/aqt.sh` añade `qtshadertools` (`lib/cmake/Qt6ShaderTools`) a su lista. La lista es la misma para los dos kits, así que `qt` y `qt-wasm` se reinstalan una vez donde ya estaban. Es la unión de lo que necesitan los proyectos, como el resto de la lista.

Alternativa descartada: **`qt-static` como host.** Tiene `qsb`, pero ataría el kit de Windows a compilar antes el estático de Linux (media hora), que no necesita para nada más.

### 3. `qt-mingw`: el kit de Qt para Windows

En `software/Qt/6.12.0-mingw`, desde los mismos tarballs de `software/src/qt-6.12.0` que `qt-static`, con su SHA-256. Necesita `gcc-mingw` y `qt`.
- **Módulos:** qtbase con Qt SQL y SQLite, qtshadertools, qtsvg, qtdeclarative y qtwebsockets, con las marcas de instalación de `qt-static` menos las de qttools. Un kit al que le falta uno se borra y se compila entero.
- **qtbase:** `configure -static -release -prefix ... -qt-host-path <kit de escritorio>`, con el fichero de toolchain de `gcc-mingw` y `QT_QMAKE_TARGET_MKSPEC=win32-g++`. Las decisiones de `qt-static`, en lo que aplica a Windows:
  - las copias propias de Qt de zlib, PCRE2, HarfBuzz, libpng, libjpeg, freetype, double-conversion y SQLite;
  - el TLS de Windows (Schannel), sin OpenSSL;
  - desactivados ICU, D-Bus, GLib, Widgets, impresión, GSSAPI, Brotli, zstd, libproxy y Vulkan;
  - los backends gráficos de Windows por defecto: Direct3D 11 y 12, y OpenGL de escritorio.

  Los nombres exactos se contrastan con el `configure -list-features` de 6.12.0 configurado para Windows, y los ajustes se anotan aquí.
- **Los demás módulos,** con el `qt-configure-module` del prefijo.
- **El riesgo principal** es GCC 16 con el TLS nativo de Windows, que nadie ha publicado con Qt. Se compila primero qtbase (tareas).

### 4. `openssl-mingw`

OpenSSL `OPENSSL_VERSION` (3.5.9, nuevo en `versions.sh`) en `software/openssl-3.5.9-mingw`. Necesita `gcc-mingw`.
- **La descarga:** el `.tar.gz` y su `.asc` de las releases de GitHub. La clave se descarga una vez de keyserver.ubuntu.com por su huella, y `VALIDSIG` tiene que dar la huella principal. `lib/common.sh` admite el sufijo de la firma (`.asc` además de `.sig`).
- **La compilación:** `./Configure mingw64 no-shared no-tests no-docs --cross-compile-prefix=<prefijo de gcc-mingw>/bin/x86_64-w64-mingw32- --prefix=... --libdir=lib`, en un directorio de compilación aparte.
- **Por qué 3.5:** es la rama LTS, hasta 2030. Las 3.6 y 4.x no lo son.

### 5. `libpq-mingw`

libpq de PostgreSQL 18.6 en `software/libpq-18.6-mingw`, desde el mismo tarball que `libpq-static`, con su SHA-256. Necesita `openssl-mingw`.
- **La compilación:** `configure --host=x86_64-w64-mingw32 --with-ssl=openssl --without-icu --without-readline --without-zlib`, con el compilador cruzado (`CC`, `AR`, `RANLIB` por su ruta) y las cabeceras y librerías de `openssl-mingw` (`CPPFLAGS`, `LDFLAGS`). Se compila la parte cliente, como en `libpq-static`.
- **La librería estática se crea a mano:**
  - `libpq.a` con `ar` sobre los objetos de `src/interfaces/libpq`;
  - se borran la DLL y la biblioteca de importación;
  - quedan `libpgcommon_shlib.a`, `libpgport_shlib.a`, las cabeceras y `pg_config.h`.
- **Las librerías de Windows** que necesita para enlazar (`ws2_32`, `secur32`, `crypt32`, ...) se documentan para los proyectos.

### 6. `protobuf-mingw`, `libpqxx-mingw` y `cpp-httplib-mingw`

Desde los mismos clones que sus componentes nativos, en directorios de compilación aparte, con el fichero de toolchain, en Release y C++26:
- **protobuf 36.2 con abseil** en `software/protobuf-36.2-mingw`, sin `protoc` (`protobuf_BUILD_PROTOC_BINARIES=OFF`), como `protobuf-wasm`;
- **libpqxx 8.0.2** en `software/libpqxx-8.0.2-mingw`, contra `libpq-mingw`, que se le pasa en `CMAKE_FIND_ROOT_PATH`;
- **cpp-httplib 0.61.0** en `software/cpp-httplib-0.61.0-mingw`, solo cabeceras y sin zlib.

Necesitan `gcc-mingw`, y libpqxx además `libpq-mingw`. `lib/common.sh` gana una función para estos builds (`cmake_mingw`), como `cmake_native` para los nativos.

### 7. Verificación, fuera del CI

- **Cada componente,** instalado desde cero, con sus ficheros y sin ninguna DLL en su prefijo.
- **El fichero de toolchain:**
  - un proyecto mínimo en `tmp/` compila un `.exe` que acepta `gcc-mingw.sh --check <ejecutable>`, y su `CMakeCache.txt` nombra el compilador del repositorio, no el de `/usr/bin`;
  - una copia del prefijo en otra ruta también funciona.
- **Programas de prueba en `tmp/`,** compilados con el fichero de toolchain y los componentes, ejecutados con Wine, con DLLs solo del sistema (`objdump -p`):
  - **Qt:** una aplicación Qt Quick mínima, que arranca en el Xvfb `:99` y muestra su ventana;
  - **libpq y OpenSSL:** un programa que se conecta con `sslmode=require` a un `postgres:18.6` efímero con TLS, y que `pg_stat_ssl` confirma;
  - **protobuf, libpqxx y cpp-httplib:** un programa que serializa un mensaje, crea una conexión de libpqxx a ese PostgreSQL y compila un servidor de cpp-httplib.
- **Los kits de aqt,** reinstalados con qtshadertools, y los demás componentes sin cambios. `install.sh --list` muestra los diecisiete.
- **Los casos de error:**
  - el tarball de OpenSSL firmado con otra clave, en un `SOFTWARE_DIR` de `tmp/`;
  - el fichero de toolchain que falta en un compilador ya instalado.

### 8. Documentación y versión

- **`docs/toolchain.md`:**
  - en la sección de `gcc-mingw`, el fichero de toolchain y cómo se usa;
  - en Componentes, una sección para Windows con los seis nuevos, sus opciones, las librerías de Windows que piden al enlazar, el tiempo y el disco;
  - en el uso desde un proyecto, el build para Windows.
- **README:** los seis componentes en la tabla.
- **CHANGELOG:** `Added` en `[Unreleased]`, que será la 0.2.0.

## Risks / Trade-offs

- [Qt 6.12 con GCC 16 y el TLS nativo de Windows] → Se compila primero qtbase. Si falla por el TLS, la salida es `gcc-mingw` sin `--enable-tls`, y con él todos los componentes `-mingw`; se anota aquí. Si es otro aviso o error de GCC 16, se corrige con la opción mínima y se anota.
- [La libpq estática a mano depende de la estructura del árbol de PostgreSQL] → El componente falla si no encuentra los objetos, y el programa de prueba no enlazaría con una biblioteca de importación.
- [Qt Quick en Wine puede no dibujar con Direct3D 11] → Wine solo es la prueba local, y se puede probar con `QSG_RHI_BACKEND=opengl`. La referencia es el Windows real, en guita#29.
- [El kit de Windows y su disco] → Como `qt-static`, puede acercarse a 40 GB en el pico. Se mide y se documenta.
- [Los kits de aqt se reinstalan por qtshadertools] → Una vez, en local y en el CI de quien fije la 0.2.0.

## Migration Plan

Todo es nuevo salvo el módulo de los kits de aqt. Al publicarse la 0.2.0, guita la fija en #29 y gambasse cuando la necesite. Deshacerlo es borrar los prefijos `-mingw` y `Qt/6.12.0-mingw`.
