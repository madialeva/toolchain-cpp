# Spec Delta

## ADDED Requirements

### Requirement: Fichero de toolchain de CMake del compilador cruzado
La instalación del compilador cruzado SHALL incluir un fichero de toolchain de CMake con el que un proyecto CMake compila para Windows de 64 bits con ese compilador, sin más configuración que la ruta al fichero y las raíces de sus dependencias. El fichero MUST localizar el compilador y sus herramientas relativo a su propia ubicación, y MUST hacer que el build no encuentre librerías ni cabeceras del sistema Linux. Si el compilador ya está instalado y le falta el fichero, el componente MUST añadirlo sin descargar ni compilar nada.

#### Scenario: Proyecto CMake para Windows
- **WHEN** se configura un proyecto CMake con el fichero de toolchain del compilador cruzado y se compila un ejecutable
- **THEN** el resultado es un ejecutable de Windows de 64 bits, compilado por el compilador cruzado del repositorio y no por otro compilador para mingw que haya en el sistema

#### Scenario: Compilador instalado sin el fichero
- **WHEN** se instala el componente sobre un compilador cruzado ya instalado que no tiene el fichero de toolchain
- **THEN** el fichero queda instalado sin descargar ni compilar nada

#### Scenario: Directorio movido
- **WHEN** se mueve el prefijo del compilador cruzado y se configura un proyecto con el fichero de toolchain de la nueva ruta
- **THEN** el proyecto usa el compilador y las herramientas de la nueva ruta

### Requirement: Excepciones estándar de C++26 con el runtime estático
Un programa en C++26 compilado con el compilador cruzado SHALL poder construir, copiar, mover, asignar y destruir las excepciones de `<stdexcept>` en cualquier nivel de optimización y enlazar con el runtime de C++ estático, sin opciones de compilación ni de enlace adicionales y sin perder las excepciones `constexpr` de C++26. Si una versión de GCC necesita un parche de sus cabeceras para ello, el componente MUST aplicarlo al instalar, y MUST aplicarlo sin descargar ni compilar nada a un compilador ya instalado que no lo tenga. La comprobación del compilador MUST cubrir estas copias con y sin optimización.

#### Scenario: Copias de excepciones sin optimizar
- **WHEN** se compila en C++26 sin optimización un programa que copia y mueve `std::logic_error`, `std::runtime_error` y `std::range_error`, y se ejecuta en Wine
- **THEN** enlaza sin definiciones múltiples y termina con el resultado esperado

#### Scenario: Excepciones en evaluación constante
- **WHEN** se compila en C++26 una función `consteval` que crea, copia y lanza una `std::range_error` y la captura
- **THEN** se evalúa en tiempo de compilación como con el compilador nativo

#### Scenario: Compilador instalado sin el parche
- **WHEN** se instala el componente sobre un compilador cruzado ya instalado cuyas cabeceras no tienen el parche
- **THEN** las cabeceras quedan parcheadas sin descargar ni compilar nada, y el compilador se comprueba de nuevo
