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
