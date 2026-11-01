# Spec Delta

## ADDED Requirements

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
