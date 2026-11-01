# Proposal

## Why

guita quiere generar su cliente autocontenido también para Windows desde Linux (guita#29), con el compilador cruzado del componente `gcc-mingw`. Ese compilador solo se ha probado con un programa de prueba. Falta todo lo que enlaza un cliente Qt con el backend de guita, compilado para Windows: Qt, la librería TLS que necesita libpq, libpq, y protobuf, libpqxx y cpp-httplib. También falta la forma de usar el compilador desde CMake.

Son piezas del toolchain, no de guita: cualquier proyecto que compile para Windows las necesita, y el kit de Qt se comparte con gambasse, como el estático de Linux. Por eso van aquí, como componentes. Es el issue #2.

## What Changes

- **Un fichero de toolchain de CMake** que instala `gcc-mingw` junto al compilador (`software/gcc-16.2.0-mingw/toolchain.cmake`), con las rutas relativas a sí mismo. Una instalación de `gcc-mingw` que ya existe lo recibe sin recompilar nada.
- **qtshadertools en los kits de aqt** (`qt`, `qt-wasm`). El build cruzado de Qt Quick necesita en el host su herramienta `qsb`.
- **Seis componentes nuevos**, compilados con `gcc-mingw`, estáticos, en prefijos `-mingw`:
  - `qt-mingw`: Qt 6.12.0 para Windows. Es un kit para todos los proyectos, con la unión de sus módulos, y con el TLS de Windows (Schannel);
  - `openssl-mingw`: OpenSSL 3.5 LTS, con la firma comprobada contra su clave fijada por huella, para el TLS de libpq;
  - `libpq-mingw`: libpq de PostgreSQL 18.6, con TLS;
  - `protobuf-mingw`, `libpqxx-mingw` y `cpp-httplib-mingw`: las librerías del backend, en C++26.
- **Documentación:** `docs/toolchain.md`, el README y el CHANGELOG. Es la versión 0.2.0: añade componentes sin tocar los existentes.

## Capabilities

### New Capabilities

Ninguna.

### Modified Capabilities

- `compilador-cruzado`: el compilador cruzado trae un fichero de toolchain de CMake, que se puede mover con él.
- `qt`: el Qt estático para Windows, compartido por los proyectos.
- `librerias`: OpenSSL, libpq y las librerías del backend para Windows.

## Impact

- **Componentes:**
  - `gcc-mingw` escribe el fichero de toolchain;
  - `qt` y `qt-wasm` llevan un módulo más: los kits instalados se reinstalan una vez;
  - seis componentes nuevos, con sus filas en `install.sh`, y la versión de OpenSSL en `versions.sh`.
- **`lib/common.sh`:** las firmas `.asc`, que es como publica OpenSSL, además de las `.sig`.
- **Proyectos:**
  - ninguno cambia por esto;
  - guita usará estos componentes en #29, fijando la 0.2.0;
  - el CI de guita, que instala `qt`, reinstalará su kit una vez cuando la fije.
- **Entorno local:** media hora larga más de compilación, sobre todo Qt, y varios GB de disco temporal.
- **Dependencias:** OpenSSL es nueva, solo para Windows. Las demás son las mismas versiones, compiladas para Windows.
