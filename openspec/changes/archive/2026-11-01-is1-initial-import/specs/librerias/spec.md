# Spec Delta

## ADDED Requirements

### Requirement: Librerías nativas
Los componentes de libpqxx, cpp-httplib y protobuf SHALL compilarlas con el compilador nativo, en C++26 y en las versiones del fichero de versiones:
- **libpqxx**, estática y PIC;
- **cpp-httplib**, solo cabeceras, con zlib y sin TLS, Brotli ni zstd;
- **protobuf con abseil**, estáticos y PIC, con su `protoc`.

Los ejecutables que instalan, como `protoc`, MUST arrancar sin `LD_LIBRARY_PATH`.

#### Scenario: protoc
- **WHEN** se ejecuta el `protoc` instalado desde una shell sin `LD_LIBRARY_PATH`
- **THEN** informa de la versión de protobuf del fichero de versiones

### Requirement: protobuf para WebAssembly
El componente de protobuf para WebAssembly SHALL compilar la misma versión de protobuf y abseil con el Emscripten del kit WebAssembly, en C++26, sin hilos y sin `protoc`. El código lo genera el `protoc` nativo.

#### Scenario: Instalación
- **WHEN** se instala el componente
- **THEN** quedan las librerías de protobuf y abseil para WebAssembly, en la misma versión que las nativas, sin ningún `protoc`

### Requirement: buf
El componente de buf SHALL instalar el binario de buf de la versión del fichero de versiones, comprobado contra las sumas que publica su release.

#### Scenario: Instalación
- **WHEN** se instala el componente
- **THEN** `buf --version` informa de esa versión

### Requirement: libpq estática
El componente de la libpq estática SHALL compilar con el compilador nativo la parte cliente de PostgreSQL, en la versión del fichero de versiones:
- las cabeceras, libpq y las librerías de PostgreSQL que necesita, y `pg_config`;
- con OpenSSL;
- sin ICU, readline ni zlib.

La libpq compartida MUST NOT quedar instalada, para que un proyecto solo pueda enlazar la estática.

#### Scenario: Instalación
- **WHEN** se instala el componente
- **THEN** su prefijo tiene `libpq.a` y las librerías que necesita, ninguna `libpq.so`, y `pg_config --version` informa de la versión del fichero de versiones
