# compilador-nativo Specification

## Purpose

El GCC compilado desde las fuentes de GNU que los proyectos usan como compilador nativo, configurado como el de la imagen oficial de GCC de su CI.

## Requirements

### Requirement: GCC nativo
El componente del compilador nativo SHALL compilar e instalar GCC, en la versión del fichero de versiones, desde las fuentes oficiales de GNU, con la firma comprobada. Lleva C y C++, y la configuración de la imagen oficial de GCC del CI de los proyectos (`--disable-multilib` y bootstrap completo), para que el compilador local y el del CI sean el mismo. El ensamblador y el enlazador MUST quedar fijados a los que hay en el PATH al compilarlo, para que un cambio posterior del PATH no le dé otros. El compilador MUST admitir C++26 y la reflexión (`-freflection`).

#### Scenario: Instalación
- **WHEN** se instala el componente en una máquina con un compilador de C++ del sistema
- **THEN** su `g++` informa de la versión del fichero de versiones, y compila un programa en C++26 que usa la reflexión

#### Scenario: GCC de la imagen del CI
- **WHEN** el prefijo del compilador nativo es un enlace a un GCC de la misma versión que ya está instalado, como el de la imagen oficial de GCC
- **THEN** el componente lo da por instalado y no compila nada
