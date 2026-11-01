# Tasks

## 1. El fichero de toolchain y qtshadertools

- [x] 1.1 Añadir a `components/gcc-mingw.sh` el fichero `toolchain.cmake` (decisión 1). Verificar:
  - que `./install.sh gcc-mingw` sobre el compilador ya instalado lo escribe sin descargar ni compilar nada;
  - que un proyecto CMake mínimo en `tmp/`, configurado con él, compila un `.exe` que `gcc-mingw.sh --check` acepta, y que su `CMakeCache.txt` nombra el `g++` de `software/gcc-16.2.0-mingw`;
  - que con una copia del prefijo en otra ruta de `tmp/` el proyecto usa la copia. Después se borra.
- [x] 1.2 Añadir `qtshadertools` a la lista de `lib/aqt.sh` (decisión 2) e instalar. Verificar que los dos kits tienen `Qt6ShaderTools` y el de escritorio `Qt6ShaderToolsTools`, y que una segunda ejecución no instala nada.
- [x] 1.3 Documentar el fichero de toolchain y qtshadertools en `docs/toolchain.md`. Verificar que coincide con los scripts.

## 2. Qt para Windows

- [ ] 2.1 Crear `components/qt-mingw.sh` con su fila en `install.sh` (decisión 3). Contrastar las opciones con `configure -list-features` de qtbase configurado para Windows, y compilar primero qtbase solo. Instalarlo, medir el tiempo y el disco, y anotar en la decisión 3 las opciones ajustadas. Verificar:
  - que tiene los cinco módulos, `plugins/platforms/libqwindows.a`, `plugins/tls/libqschannelbackend.a` y `plugins/sqldrivers/libqsqlite.a`, y ninguna DLL;
  - que su `qt.toolchain.cmake` encadena `software/gcc-16.2.0-mingw/toolchain.cmake`;
  - que una aplicación Qt Quick mínima, compilada en `tmp/` con el kit, solo importa DLLs de Windows y, con Wine en el Xvfb `:99`, muestra su ventana. Anotar si hizo falta otro backend de RHI.
- [ ] 2.2 Documentar `qt-mingw` en `docs/toolchain.md` y el README. Verificar que coincide con el script.

## 3. OpenSSL, libpq y las librerías del backend para Windows

- [ ] 3.1 Admitir en `lib/common.sh` firmas `.asc`, añadir `OPENSSL_VERSION` a `versions.sh`, y crear `components/openssl-mingw.sh` y `components/libpq-mingw.sh` (decisiones 4 y 5). Instalarlos. Verificar:
  - que los dos prefijos tienen sus librerías estáticas y ninguna DLL, y que la `libpq.a` tiene objetos de libpq, no un import de `libpq.dll`;
  - que un programa en `tmp/` que se conecta con `sslmode=require` a un `postgres:18.6` efímero con TLS (certificado autofirmado), ejecutado con Wine, se conecta cifrado según `pg_stat_ssl`, y solo importa DLLs de Windows;
  - que con un `SOFTWARE_DIR` de `tmp/` y el keyring de GNU en lugar de la clave de OpenSSL, `openssl-mingw` falla antes de compilar nombrando el tarball.
- [ ] 3.2 Añadir `cmake_mingw` a `lib/common.sh` y crear `components/protobuf-mingw.sh`, `libpqxx-mingw.sh` y `cpp-httplib-mingw.sh` (decisión 6). Instalarlos. Verificar:
  - que los tres prefijos tienen sus librerías y su configuración de CMake, ninguna DLL, y el de protobuf ningún `protoc`;
  - que un programa en `tmp/`, compilado con los tres y con un `.proto` generado por el `protoc` nativo, serializa un mensaje, abre una conexión de libpqxx al PostgreSQL de la tarea 3.1, compila un `httplib::Server` y, con Wine, termina con el resultado esperado.
- [ ] 3.3 Documentar los cinco componentes en `docs/toolchain.md` (con las librerías de Windows que piden al enlazar) y el README, el uso desde un proyecto para Windows, y el CHANGELOG. Verificar:
  - que `install.sh --list` muestra los diecisiete componentes;
  - que una segunda ejecución de `./install.sh` con todos no instala nada;
  - que la documentación coincide con los scripts.

## 4. Verificación

- [ ] 4.1 El usuario hace push de la rama y el CI pasa.
- [ ] 4.2 El usuario revisa el cambio y da el visto bueno.
