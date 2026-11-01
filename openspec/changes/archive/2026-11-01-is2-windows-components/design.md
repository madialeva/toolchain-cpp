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

Ajustes y resultados al implementar:
- **GCC 16 y el TLS nativo no dieron ningún problema.** qtbase compiló en 6 minutos, y el kit entero en 26.
- **`configure` aceptó las opciones tal cual.** El resumen da Schannel sin OpenSSL, las copias de Qt de todas las librerías, OpenGL de escritorio, Direct2D y DirectWrite, y nada de X11 ni Wayland. Solo avisa de que mingw-w64 no trae cppwinrt, que Qt usa para algunas funciones opcionales de Windows.
- **Los demás módulos se configuran sin el fichero de toolchain del compilador.** `qt-configure-module` usa el `qt.toolchain.cmake` del kit, que encadena el del compilador y añade el kit a las raíces de búsqueda. Pasarle el del compilador, como al principio, le ocultaba el kit a `find_package(Qt6)`.
- **Una aplicación Qt Quick mínima** pesa 46 MB sin símbolos y solo importa DLLs de Windows (Direct3D 9, 11 y 12, DXGI, DirectWrite, OpenGL, Winsock, Schannel, y los conjuntos de API del UCRT y de WinRT). En Wine se dibuja con Direct3D 11.
- **Wine 10.6 no implementa `mscms.dll.WcsCreateIccProfile`**, que Qt llama al leer el perfil de color de la pantalla: la aplicación se aborta. Windows la tiene desde Vista. Para la prueba en Wine se quita el perfil sRGB del prefijo temporal (`windows/system32/spool/drivers/color`).
- **Disco:** cerca de 40 GB en el pico, como `qt-static`; el kit ocupa 0,7 GB.

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

Ajustes al implementar:
- **`OpenSSL` sin módulos (`no-module`):** sin esa opción instala `ossl-modules/legacy.dll`.
- **De `src/interfaces/libpq` quedan fuera** `fe-auth-oauth_shlib.o` y los demás `*_shlib.o`, que son de la DLL, y `win32ver.o`, su recurso de versión, que chocaría con el del ejecutable.
- **libpq necesita la variante `_shlib` de `libpgcommon` y `libpgport`:** la de frontend usa nombres de codificación privados y deja `pg_encoding_to_char` sin definir. De `libpgcommon_shlib.a` se borran `exec_shlib.o` y `restricted_token_shlib.o`. `exec.c` define `_dowildcard`, que el `crt2.o` de mingw busca, así que el enlazador lo saca del archivo y con él código que necesita el `palloc` del servidor. libpq no usa ninguno de los dos.
- **libpq trae sus propias funciones de hilos para Windows** (`pthread-win32.c`: `pthread_self`, `pthread_mutex_lock`, ...), con un `pthread_mutex_t` propio (un `CRITICAL_SECTION`). Un programa en C++ enlaza también winpthreads, y las dos definiciones chocan. Quitar el objeto de libpq no vale: sus llamadas irían a winpthreads con otro tipo de mutex. Con `objcopy --redefine-syms` se renombran con el prefijo `pq_` en todos los objetos de libpq, en las definiciones y en las llamadas, y el componente falla si queda algún `pthread_` en `libpq.a`. La prueba en C de la tarea 3.1 no lo vio porque no enlaza winpthreads.

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
  - en la sección de `gcc-mingw`, el fichero de toolchain y cómo se usa, y el parche de las cabeceras (decisión 9);
  - en Componentes, una sección para Windows con los seis nuevos, sus opciones, las librerías de Windows que piden al enlazar, el tiempo y el disco;
  - en el uso desde un proyecto, el build para Windows.
- **README:** los seis componentes en la tabla.
- **CHANGELOG:** `Added` en `[Unreleased]`, que será la 0.2.0.

### 9. Las excepciones de C++26 en mingw: un parche de las cabeceras de libstdc++

Apareció al enlazar el programa de prueba de la tarea 3.2. En C++26 (`__cpp_lib_constexpr_exceptions` 202502), las cabeceras de libstdc++ de GCC 16 definen en línea, para que sean `constexpr`, miembros de las excepciones de `<stdexcept>` que `libstdc++.a` también define fuera de línea (`stdexcept.cc`, `cow-stdexcept.cc`, `cxx11-stdexcept.cc`). En ELF las copias en línea son débiles y no pasa nada. En PE/COFF chocan con las del archivo y el enlace falla con definiciones múltiples:
- el destructor de `std::range_error` en cuanto se emite su vtable, también optimizando (abseil lo hace);
- sin optimizar, además, los constructores de `std::range_error` y la copia y el movimiento de `std::logic_error` y `std::runtime_error`.

Es el bug 125151 de GCC, abierto desde mayo de 2026 y sin arreglar en 16.2.0. Afecta a cualquier proyecto en C++26 para Windows, guita incluido, que lanza `std::invalid_argument`.

libstdc++ ya resuelve lo mismo en las demás excepciones con `[[__gnu__::__gnu_inline__]]`: la definición en línea sirve para la evaluación constante y para insertarla, pero nunca se emite, y una llamada que no se inserta usa el símbolo de la librería. Al upstream se le escaparon esos miembros. `patches/gcc-16.2.0-mingw-stdexcept.patch` les pone el mismo atributo (y `inline` a la asignación por copia de `runtime_error`, que no es `constexpr` y sin él lo ignora). Todos esos símbolos están en `libstdc++.a`, así que basta con las cabeceras y la librería no se recompila.

- **`gcc-mingw.sh` aplica los parches de `patches/gcc-<versión>-mingw-*.patch`** a las cabeceras instaladas, con `patch -p1`, al final de la instalación. Como con el fichero de toolchain, `is_installed` exige que estén aplicados (lo comprueba `patch -R --dry-run`), y un compilador ya instalado sin ellos los recibe sin recompilar y se comprueba de nuevo. Un parche que no aplica para la instalación.
- **La comprobación del compilador** copia, mueve y asigna esas tres excepciones, y compila el programa también sin optimizar. Con las cabeceras sin parchear, falla el enlace en los dos niveles. Así, si se sube de versión GCC y el bug sigue sin parche, se ve.
- **Solo el compilador cruzado.** El nativo no lo necesita (ELF), y el CI usa la imagen `gcc:16.2.0-trixie`, que no se parchea.
- **Las librerías compiladas antes del parche** llevan las copias que chocan. De los componentes, solo `libabsl_throw_delegate.a` (abseil, en `protobuf-mingw`), que se recompiló. Qt, libpqxx y cpp-httplib no tenían ninguna.

Comprobado con un programa que construye, copia, mueve, asigna y lanza las nueve excepciones de `<stdexcept>` y provoca una de `libstdc++.a` (`vector::at`): en C++23 y C++26, con `-O0`, `-O2` y `-Os`, enlaza y termina bien en Wine. Una función `consteval` que crea, copia y lanza una `std::range_error` se sigue evaluando.

Alternativas descartadas:
- **`-D__cpp_lib_constexpr_exceptions=0`,** el apaño del informe. Cambia el comportamiento de la librería en cada proyecto y quita las excepciones `constexpr`.
- **Debilitar los símbolos de `libstdc++.a` con `objcopy --weaken`.** Enlaza, pero en PE los símbolos débiles son externos débiles de COFF: el ejecutable salta a una dirección nula al arrancar, también en C++23.
- **`-Wl,--allow-multiple-definition`** en los proyectos. Oculta cualquier otro choque de verdad.
- **Compilar en C++23 lo que lanza excepciones.** Abseil y los proyectos son C++26.
- **Recompilar GCC con el parche en las fuentes.** El resultado es el mismo, porque solo cambian cabeceras, y costaría un cuarto de hora y rehacer todos los componentes `-mingw`.

## Risks / Trade-offs

- [Qt 6.12 con GCC 16 y el TLS nativo de Windows] → Se compila primero qtbase. Si falla por el TLS, la salida es `gcc-mingw` sin `--enable-tls`, y con él todos los componentes `-mingw`; se anota aquí. Si es otro aviso o error de GCC 16, se corrige con la opción mínima y se anota.
- [La libpq estática a mano depende de la estructura del árbol de PostgreSQL] → El componente falla si no encuentra los objetos, y el programa de prueba no enlazaría con una biblioteca de importación.
- [Qt Quick en Wine puede no dibujar con Direct3D 11] → Wine solo es la prueba local, y se puede probar con `QSG_RHI_BACKEND=opengl`. La referencia es el Windows real, en guita#29.
- [El kit de Windows y su disco] → Como `qt-static`, puede acercarse a 40 GB en el pico. Se mide y se documenta.
- [Los kits de aqt se reinstalan por qtshadertools] → Una vez, en local y en el CI de quien fije la 0.2.0.
- [Un parche propio en las cabeceras de GCC (decisión 9)] → Es pequeño, copia lo que libstdc++ ya hace con las demás excepciones, y va con la versión de GCC en el nombre. Cuando GCC arregle el bug 125151, se quita en la versión que lo traiga; si se sube GCC sin él y el bug sigue, la comprobación del compilador falla.

## Migration Plan

Todo es nuevo salvo el módulo de los kits de aqt. Al publicarse la 0.2.0, guita la fija en #29 y gambasse cuando la necesite. Deshacerlo es borrar los prefijos `-mingw` y `Qt/6.12.0-mingw`.
