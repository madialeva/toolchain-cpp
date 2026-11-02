# Proposal

## Why

Los scripts del repositorio son todo el producto: `install.sh`, `versions.sh`, `lib/*.sh`, los diecisiete `components/*.sh` y `scripts/check-version.sh`. El CI solo comprueba su sintaxis con `bash -n`, que no ve variables mal escritas, comillas que faltan, ni `source` que apuntan a otro sitio. Los scripts nunca han pasado por shellcheck: el change `initial-import` lo dejó fuera porque arreglar lo que dijera habría cambiado el código importado de guita (su Non-Goal). Es el issue #3.

Ahora el coste es bajo. Con shellcheck 0.11.0 y los `source` resueltos desde el directorio de cada script, solo quedan dos avisos de estilo en `components/gcc-mingw.sh`. Las directivas `# shellcheck shell=bash` y `# shellcheck source=` ya están en su sitio. Empezar ahora, antes de que crezcan los componentes, mantiene la comprobación limpia desde el principio.

## What Changes

- **`scripts/check-scripts.sh`**: comprueba todos los scripts, igual en local que en el CI. Primero la sintaxis (`bash -n`), como hasta ahora, y después shellcheck en una versión fijada (0.11.0). Si la del PATH no es esa, descarga el binario oficial, comprobado contra su SHA-256 fijado. En el CI, cada aviso se anota en su fichero y su línea.
- **`.shellcheckrc`** en la raíz: los `source` se resuelven desde el directorio de cada script y se siguen. El script, el CI y el shellcheck de un editor dan lo mismo.
- **El CI**: el paso de sintaxis del trabajo `Version and syntax` se sustituye por `scripts/check-scripts.sh`, y el trabajo pasa a llamarse `Version and scripts`.
- **Los avisos actuales**: los dos `SC2001` de `components/gcc-mingw.sh`, que sangran un texto de varias líneas con `sed`, se silencian en su sitio, con el motivo.
- **Documentación**: AGENTS.md (Verification y Local environment) y `docs/toolchain.md`. No hay entrada en el CHANGELOG: ni los proyectos ni quien instala el toolchain lo notan.

## Capabilities

### New Capabilities

Ninguna.

### Modified Capabilities

- `integracion-continua`: el CI comprueba los scripts con shellcheck además de su sintaxis, y la misma comprobación se puede ejecutar en local.

## Impact

- **Ficheros nuevos:** `scripts/check-scripts.sh` y `.shellcheckrc`.
- **Modificados:** `.github/workflows/ci.yml`, `components/gcc-mingw.sh` (dos directivas), AGENTS.md y `docs/toolchain.md`.
- **Componentes y proyectos:** ninguno cambia lo que instala ni cómo se usa.
- **Dependencias:** shellcheck 0.11.0 solo para comprobar los scripts: el del PATH si es esa versión, o si no descargado bajo demanda en `software/src`, sin instalar nada en el sistema. El script necesita `curl`, `tar` con xz y `sha256sum`.
- **Versión:** sin cambio. Es trabajo interno del ciclo 0.2.0.
