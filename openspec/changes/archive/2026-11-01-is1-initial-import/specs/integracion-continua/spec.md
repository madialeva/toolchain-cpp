# Spec Delta

## ADDED Requirements

### Requirement: CI del repositorio
Cada push a una rama `develop/**` o `release/**`, y cada pull request hacia una de ellas, SHALL ejecutar el CI del repositorio en GitHub Actions. El CI MUST:
- comprobar que la versión del repositorio coincide con la de la rama;
- comprobar la sintaxis de todos los scripts;
- instalar desde cero componentes rápidos, con el GCC de la imagen oficial de GCC.

MUST NOT compilar GCC ni Qt.

#### Scenario: Versión que no coincide
- **WHEN** se hace push a `develop/v0.2.0` con la versión `0.1.0` en el repositorio
- **THEN** el CI falla e indica las dos versiones

#### Scenario: Error de sintaxis
- **WHEN** un script tiene un error de sintaxis de bash
- **THEN** el CI falla y nombra el script

#### Scenario: Instalación de prueba
- **WHEN** el CI se ejecuta sobre un cambio correcto
- **THEN** instala los componentes de prueba con el GCC de la imagen enlazado como compilador nativo, y termina sin errores
