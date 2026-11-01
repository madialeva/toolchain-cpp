# Spec Delta

## ADDED Requirements

### Requirement: Componentes por nombre
El repositorio SHALL tener una única entrada que instala los componentes que se le nombran. Instala también cada componente del que dependen que no esté instalado, siempre antes que los que dependen de él. Un nombre que no es de ningún componente MUST hacer fallar la entrada antes de instalar nada, con la lista de los nombres válidos. La entrada MUST poder listar los componentes con su versión y si están instalados, y mostrar lo que instalaría sin hacerlo.

#### Scenario: Componente con dependencias
- **WHEN** se pide instalar un componente que necesita otro que no está instalado
- **THEN** se instala primero el que falta y después el pedido

#### Scenario: Nombre desconocido
- **WHEN** se pide un componente que no existe
- **THEN** falla sin instalar nada y muestra los nombres válidos

#### Scenario: Lista
- **WHEN** se piden los componentes
- **THEN** se muestra cada uno con su versión y si está instalado

#### Scenario: Plan sin instalar
- **WHEN** se pide lo que se instalaría para unos componentes
- **THEN** se muestran, en orden, los que se instalarían, sin descargar ni compilar nada

### Requirement: Directorio de instalación
Todo lo que se descarga, se compila y se instala SHALL ir a un único directorio. Por defecto es un directorio del repositorio que git ignora, y una variable de entorno lo cambia. Cada componente MUST instalarse en su propio prefijo dentro de él, con un nombre que incluye su versión. Esa estructura es lo que usan los proyectos. La instalación MUST NOT necesitar root, y MUST NOT escribir fuera de ese directorio, salvo el Python que gestiona uv en su ubicación estándar.

#### Scenario: Directorio por defecto
- **WHEN** se instala un componente sin la variable del directorio
- **THEN** queda en el directorio ignorado del repositorio, y `git status` no lo muestra

#### Scenario: Otro directorio
- **WHEN** se instala un componente con la variable del directorio apuntando a otra ruta
- **THEN** sus fuentes y su prefijo quedan en esa ruta, y el directorio del repositorio no cambia

#### Scenario: Sin root
- **WHEN** un usuario sin privilegios instala cualquier componente
- **THEN** se instala sin pedir `sudo`

### Requirement: Lo instalado no se repite
Un componente ya instalado SHALL darse por instalado sin descargar ni compilar nada. Una instalación que no terminó MUST NOT darse por instalada, y la siguiente MUST empezar ese componente de nuevo.

#### Scenario: Segunda ejecución
- **WHEN** se pide instalar componentes que ya están instalados
- **THEN** termina sin descargar ni compilar nada

#### Scenario: Instalación interrumpida
- **WHEN** una ejecución anterior se interrumpió a mitad de un componente
- **THEN** la siguiente no lo da por instalado y lo instala desde el principio

### Requirement: Descargas comprobadas
Cada descarga SHALL comprobarse antes de compilar o borrar nada, por este orden de preferencia:
- con su firma, cuando el proyecto de origen la publica. Si la clave no está en un keyring publicado del proyecto de origen, MUST exigirse la huella fijada en el repositorio;
- si no hay firma, con la suma de comprobación que publica su servidor;
- si se clona de git, con la etiqueta de la versión en el repositorio oficial.

Una descarga que no coincide MUST hacer fallar la instalación antes de compilar, nombrando el fichero, sin instalar nada.

#### Scenario: Descarga alterada
- **WHEN** un fichero descargado no coincide con su firma o con su suma publicada
- **THEN** la instalación falla antes de compilar, nombra el fichero y no deja nada instalado de ese componente

#### Scenario: Firma de otra clave
- **WHEN** un fichero está firmado correctamente, pero con otra clave que la fijada para él
- **THEN** la instalación falla igual que con una firma incorrecta

### Requirement: Uso desde un proyecto
El repositorio SHALL documentar cómo un proyecto clonado a su lado (`../toolchain-cpp`) usa los componentes instalados:
- desde sus presets de CMake, sin variables de entorno;
- desde sus scripts;
- desde su CI, con la versión de este repositorio que fija el proyecto.

Las rutas que documenta MUST ser las de la estructura del directorio de instalación.

#### Scenario: Un proyecto junto al repositorio
- **WHEN** un proyecto clonado junto a este repositorio configura un preset que apunta a los componentes instalados con una ruta relativa al proyecto
- **THEN** encuentra el compilador, Qt y las librerías, y compila
