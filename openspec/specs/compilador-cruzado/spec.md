# compilador-cruzado Specification

## Purpose

El GCC cruzado que genera desde Linux ejecutables de Windows de 64 bits que solo necesitan DLLs del sistema, su fichero de toolchain de CMake y su comprobación.

## Requirements

### Requirement: Compilador cruzado para Windows
El componente del compilador cruzado SHALL compilar e instalar un compilador de C y C++ que se ejecuta en Linux y genera ejecutables de Windows de 64 bits (x86_64). Lo compila con el compilador nativo del repositorio, desde las fuentes oficiales de GCC, binutils y mingw-w64, en las versiones y con las opciones de configuración que se fijan en el repositorio. El compilador cruzado MUST ser la misma versión de GCC que el nativo.

#### Scenario: Primera instalación
- **WHEN** se instala el componente con el compilador nativo instalado
- **THEN** el compilador cruzado queda en su prefijo, informa de la misma versión de GCC que el nativo, y el nativo no cambia

#### Scenario: Directorio movido
- **WHEN** se mueve el prefijo del compilador cruzado a otra ruta
- **THEN** sigue encontrando sus cabeceras, sus librerías y sus herramientas en la ruta nueva

### Requirement: Ejecutables de Windows sin DLLs del runtime
Los ejecutables que genera el compilador cruzado SHALL necesitar solo DLLs del sistema operativo: las del núcleo de Windows (como `KERNEL32.dll`) y las del runtime de C universal (UCRT). El runtime de C++ y el de hilos MUST quedar dentro del ejecutable sin opciones de compilación ni de enlace adicionales. Los ejecutables MUST poder ejecutarse en Windows 10 (versión 1809 o posterior) y Windows 11 de 64 bits, y MUST admitir los hilos, las variables `thread_local` y las excepciones de C++.

#### Scenario: Programa con hilos y excepciones
- **WHEN** se compila sin opciones adicionales un programa en C++26 que crea hilos, usa una variable `thread_local` en cada uno y lanza y captura una excepción, y se ejecuta en Windows 10 u 11 de 64 bits o en Wine, sin ninguna DLL a su lado
- **THEN** termina con el resultado esperado

#### Scenario: DLLs que importa
- **WHEN** se listan las DLLs que importa un ejecutable generado sin opciones adicionales
- **THEN** solo aparecen DLLs del núcleo de Windows y del UCRT, y ninguna del runtime de GCC (`libstdc++-6.dll`, `libgcc_s_seh-1.dll`, `libwinpthread-1.dll`) ni el runtime de C antiguo (`msvcrt.dll`)

### Requirement: Comprobación del compilador cruzado
La instalación del compilador cruzado SHALL terminar comprobándolo, y la comprobación SHALL poder repetirse a demanda sobre el compilador ya instalado. La comprobación MUST compilar un programa de prueba en C++26 que use hilos, variables `thread_local`, excepciones y punteros compartidos. MUST fallar si el ejecutable necesita alguna DLL que no sea del sistema, nombrándola. La comprobación de las DLLs SHALL poder aplicarse también a un ejecutable dado. Si Wine está instalado, la comprobación MUST ejecutar el programa de prueba con él, sin abrir ventanas ni tocar la configuración de Wine del usuario, y MUST fallar si el programa no termina con el resultado esperado. Sin Wine, MUST avisar de que no lo ha ejecutado, sin fallar por ello.

#### Scenario: Compilador correcto
- **WHEN** se ejecuta la comprobación sobre el compilador cruzado instalado, en una máquina con Wine
- **THEN** termina sin errores y muestra las DLLs que importa el programa de prueba, todas del sistema, y la salida de ejecutarlo

#### Scenario: Una DLL que sobra
- **WHEN** se comprueba un ejecutable que importa una DLL que no es del sistema, como `libstdc++-6.dll`
- **THEN** la comprobación falla y nombra esa DLL

#### Scenario: Sin Wine
- **WHEN** se ejecuta la comprobación en una máquina sin Wine
- **THEN** comprueba las DLLs del programa de prueba, avisa de que no lo ha ejecutado y termina sin error si las DLLs son correctas

#### Scenario: Configuración de Wine del usuario
- **WHEN** la comprobación ejecuta el programa de prueba con Wine
- **THEN** no se abre ninguna ventana, y el prefijo de Wine del usuario (`~/.wine`) no se crea ni cambia

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
