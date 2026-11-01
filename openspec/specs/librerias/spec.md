# librerias Specification

## Purpose

Las librerías y herramientas que usan los proyectos, en las versiones del repositorio: libpqxx, cpp-httplib, protobuf para nativo y para WebAssembly, buf y libpq estática, y para Windows OpenSSL, libpq, libpqxx, cpp-httplib y protobuf.

## Requirements

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

### Requirement: OpenSSL para Windows
El componente de OpenSSL para Windows SHALL compilar con el compilador cruzado la versión de OpenSSL del fichero de versiones, de su rama LTS, estática, desde el tarball oficial con su firma comprobada contra la clave de firma del proyecto, fijada por su huella.

#### Scenario: Instalación
- **WHEN** se instala el componente
- **THEN** su prefijo tiene `libssl.a` y `libcrypto.a` para Windows, y ninguna DLL

#### Scenario: Firma de otra clave
- **WHEN** el tarball está firmado correctamente, pero con otra clave que la fijada
- **THEN** la instalación falla antes de compilar y nombra el fichero

### Requirement: libpq para Windows
El componente de libpq para Windows SHALL compilar con el compilador cruzado la parte cliente de PostgreSQL, en la versión del fichero de versiones, con el TLS del componente de OpenSSL para Windows. MUST instalar una `libpq.a` estática, con el código de libpq dentro y no la biblioteca de importación de una DLL, y las librerías de PostgreSQL que necesita. MUST NOT instalar ninguna DLL. La `libpq.a` MUST NOT definir símbolos que choquen con los del runtime del compilador cruzado, como las funciones de hilos POSIX de winpthreads.

#### Scenario: Un programa con libpq
- **WHEN** se compila para Windows un programa que llama a libpq y abre una conexión con TLS obligatorio a un PostgreSQL con TLS, y se ejecuta en Wine
- **THEN** se conecta cifrando la conexión, y el ejecutable no importa ninguna DLL de PostgreSQL ni de OpenSSL

#### Scenario: Un programa en C++ con libpq
- **WHEN** se compila para Windows un programa en C++ que usa libpq, con lo que también enlaza winpthreads
- **THEN** enlaza sin definiciones múltiples, y libpq sigue usando sus propias funciones de hilos

### Requirement: Librerías del backend para Windows
Los componentes de protobuf, libpqxx y cpp-httplib para Windows SHALL compilarlas con el compilador cruzado, en C++26 y en las mismas versiones que las nativas, estáticas:
- **protobuf con abseil**, sin `protoc`, porque el código lo genera el `protoc` nativo;
- **libpqxx**, contra la libpq para Windows;
- **cpp-httplib**, solo cabeceras y sin zlib.

#### Scenario: Instalación
- **WHEN** se instalan los tres componentes
- **THEN** cada prefijo tiene sus librerías estáticas para Windows y su configuración de CMake, ninguna DLL, y el de protobuf ningún `protoc`
