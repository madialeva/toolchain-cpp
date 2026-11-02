# Spec Delta

## MODIFIED Requirements

### Requirement: CI del repositorio
Cada push a una rama `develop/**` o `release/**`, y cada pull request hacia una de ellas, SHALL ejecutar el CI del repositorio en GitHub Actions. El CI MUST:
- comprobar que la versión del repositorio coincide con la de la rama;
- comprobar todos los scripts con la comprobación de los scripts del repositorio: su sintaxis y shellcheck;
- instalar desde cero componentes rápidos, con el GCC de la imagen oficial de GCC.

MUST NOT compilar GCC ni Qt.

#### Scenario: Versión que no coincide
- **WHEN** se hace push a `develop/v0.2.0` con la versión `0.1.0` en el repositorio
- **THEN** el CI falla e indica las dos versiones

#### Scenario: Error de sintaxis
- **WHEN** un script tiene un error de sintaxis de bash
- **THEN** el CI falla y nombra el script

#### Scenario: Aviso de shellcheck
- **WHEN** un script tiene algo que shellcheck señala, como una variable sin comillas que puede partirse en palabras
- **THEN** el CI falla y anota el aviso en el fichero y la línea del script

#### Scenario: Instalación de prueba
- **WHEN** el CI se ejecuta sobre un cambio correcto
- **THEN** instala los componentes de prueba con el GCC de la imagen enlazado como compilador nativo, y termina sin errores

## ADDED Requirements

### Requirement: Comprobación de los scripts
El repositorio SHALL tener una comprobación de los scripts que se ejecute igual en local y en el CI. MUST abarcar `install.sh`, `versions.sh` y todos los scripts de `lib/`, `components/` y `scripts/`, incluidos los que se añadan. MUST comprobar su sintaxis de bash y pasarlos por shellcheck con todas sus comprobaciones por defecto, incluidas las de estilo, siguiendo los ficheros que cargan con `source`. MUST usar una versión de shellcheck fijada en el repositorio. Si la del sistema es otra o no hay ninguna, MUST descargar la versión fijada, comprobarla contra su suma fijada antes de usarla, y no instalar nada fuera del directorio de instalación del repositorio. MUST fallar si algún script tiene un error o un aviso, nombrando el script, la línea y el código del aviso. Un aviso que no se corrige MUST silenciarse en su línea, con el motivo escrito al lado.

#### Scenario: Scripts limpios
- **WHEN** se ejecuta la comprobación sobre el repositorio sin avisos
- **THEN** termina sin error e indica cuántos scripts ha comprobado y con qué versión de shellcheck

#### Scenario: Sin shellcheck en el sistema
- **WHEN** se ejecuta la comprobación en una máquina sin shellcheck, o con otra versión
- **THEN** descarga la versión fijada, comprueba su suma y la usa, y en la siguiente ejecución la reutiliza sin descargarla

#### Scenario: Descarga que no coincide
- **WHEN** el binario descargado no coincide con la suma fijada
- **THEN** la comprobación falla antes de ejecutarlo, nombrando el fichero

#### Scenario: Script nuevo
- **WHEN** se añade un componente nuevo en `components/` con un aviso de shellcheck
- **THEN** la comprobación lo incluye sin cambiarla, y falla nombrando ese script
