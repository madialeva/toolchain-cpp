# Design

## Context

- **Los scripts:** son 22 ficheros de bash en cinco grupos: `install.sh`, `versions.sh`, `lib/common.sh` y `lib/aqt.sh` (que se cargan con `source`), los diecisiete `components/*.sh` y `scripts/check-version.sh`. Los que se cargan llevan `# shellcheck shell=bash`, y cada `source` lleva su `# shellcheck source=<ruta relativa al script>`.
- **El CI:** el trabajo `Version and syntax` (`ubuntu-24.04`) recorre esa lista con `bash -n` en un paso propio y anota cada error con `::error file=...`.
- **Lo que dice shellcheck 0.11.0 hoy:**
  - sin más opciones que `-x`, da 74 avisos, que no son de verdad: 20 `SC1091` porque las rutas de `source=` se resuelven desde el directorio actual y no desde el del script, y 52 `SC2034` (`NAME`, `VERSION`, `PREFIXES`, `USAGE` sin usar) porque no llega a ver `lib/common.sh`, que es quien los usa;
  - con los `source` resueltos desde el directorio del script (`source-path=SCRIPTDIR`), solo quedan dos `SC2001` (estilo) en `components/gcc-mingw.sh`. Los dos son `sed 's/^/  /' <<<"$text"`, que sangran cada línea de un texto de varias;
  - con las comprobaciones opcionales (`--enable=all`) salen más de 700 avisos: 674 piden llaves en cada variable (`SC2250`), y el resto son funciones-predicado en condiciones (`SC2310`), `$(...)` dentro de otros comandos (`SC2312`), variables que vienen de `versions.sh` (`SC2154`) y `case` sin `*)` (`SC2249`). Son patrones deliberados del código, no errores.
- **shellcheck en las máquinas:**
  - la de desarrollo (Oracle Linux 9) tiene el 0.10.0 de EPEL, que hoy da los mismos dos avisos que el 0.11.0 con el `.shellcheckrc`;
  - el runner `ubuntu-24.04` trae el de su distribución, una versión anterior que cambia con la imagen;
  - la última versión, 0.11.0 (agosto de 2025), se publica en GitHub como binario estático para Linux x86_64 (`shellcheck-v0.11.0.linux.x86_64.tar.xz`), con el SHA-256 de cada fichero en los datos de la release: `8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198`.

## Goals / Non-Goals

**Goals:**
- Que todos los scripts pasen shellcheck, con sus comprobaciones por defecto, y que el CI lo exija desde ya.
- La misma comprobación, con el mismo resultado, en local, en el CI y en un editor.
- Una versión de shellcheck fijada, para que una imagen nueva del runner no cambie el resultado.

**Non-Goals:**
- **Las comprobaciones opcionales de shellcheck** (`--enable=all`). Son cientos de avisos de estilo deliberado. Si alguna (por ejemplo `SC2312`, retornos enmascarados) resulta útil, irá en otro change.
- **El bash que hay dentro de `.github/workflows/ci.yml`.** Lo comprobaría actionlint, que es otra herramienta.
- **Formatear los scripts** (shfmt).
- **Hacer de shellcheck un componente.** Los componentes son lo que usan los proyectos; shellcheck solo lo usa este repositorio.

## Decisions

### 1. `scripts/check-scripts.sh`, la comprobación única

Un script, con el estilo de `scripts/check-version.sh`, que ejecutan igual el desarrollador y el CI:

1. **Los ficheros:** `install.sh`, `versions.sh`, `lib/*.sh`, `components/*.sh` y `scripts/*.sh`, por patrón. Un componente nuevo entra solo.
2. **La sintaxis:** `bash -n` en cada uno, como el paso actual del CI. Si alguno falla, el script termina ahí, porque shellcheck no aportaría nada sobre un fichero que no se puede leer.
3. **shellcheck:** todos los ficheros en una sola llamada, con la severidad por defecto (también `style`), con `-f gcc` (`fichero:línea:columna: nivel: mensaje [SCxxxx]`). Al final dice cuántos scripts ha comprobado y con qué versión, o termina con error.
4. **En el CI** (`GITHUB_ACTIONS=true`): cada línea de shellcheck y cada fallo de sintaxis también se escribe como `::error file=...,line=...,col=...::` o `::warning ...`, según el nivel, para que el aviso aparezca en el fichero dentro del diff de la PR.

El paso `Check the syntax of the scripts` del CI pasa a ser `Check the scripts`, con `run: scripts/check-scripts.sh`, y el trabajo `Version and syntax` pasa a llamarse `Version and scripts`. Ninguna regla de las ramas exige ese check por su nombre (no hay protección ni rulesets), así que el cambio de nombre no bloquea nada.

Alternativas descartadas:
- **Dos pasos en el CI (sintaxis y shellcheck) sin script.** En local no habría forma de reproducirlo, y la lista de ficheros quedaría repetida.
- **Una acción de terceros** (`ludeeus/action-shellcheck`). Fija la versión dentro de la acción y no se puede ejecutar en local.

### 2. shellcheck 0.11.0, fijado y descargado bajo demanda

`scripts/check-scripts.sh` fija `SHELLCHECK_VERSION=0.11.0` y el SHA-256 de su tarball oficial para Linux x86_64, y elige el shellcheck así:
- **El del PATH,** si `shellcheck --version` da esa versión.
- **Si no, el del directorio de instalación:** `$SOFTWARE_DIR/src/shellcheck-v0.11.0/shellcheck`, si ya está.
- **Si tampoco, lo descarga de las releases de GitHub** a `$SOFTWARE_DIR/src`, con `download` de `lib/common.sh`, comprueba el SHA-256 contra el fijado y solo entonces lo extrae. Si no coincide, falla nombrando el fichero, sin ejecutar nada.

Usa `lib/common.sh` (para `SOFTWARE_DIR`, `say`, `die` y `download`) y, como en los componentes, no instala nada fuera de `software/`. En otra arquitectura que no sea x86_64, falla diciendo que haría falta shellcheck 0.11.0 en el PATH.

Por qué fijada y no la del runner ni la del sistema: avisos nuevos de otra versión harían fallar el CI sin cambiar ningún script, y en local saldría otra cosa. Subir de versión es cambiar las dos constantes y arreglar lo que diga la nueva, en un change. Un shellcheck del sistema de otra versión (el 0.10.0 de EPEL) sigue sirviendo al editor, que lee el mismo `.shellcheckrc`; el script usa el fijado.

Por qué la suma está en el script: shellcheck no publica un fichero de sumas aparte; GitHub da el SHA-256 de cada fichero de la release, que se copia aquí, como el fingerprint de una clave fijada (`docs/toolchain.md` §1.4).

### 3. `.shellcheckrc` en la raíz

```text
source-path=SCRIPTDIR
external-sources=true
```

- `source-path=SCRIPTDIR`: las rutas de `# shellcheck source=` son relativas al script, que es como están escritas. Sin esto salen los 20 `SC1091`.
- `external-sources=true`: sigue los `source` (lo mismo que `-x`). Al ver `lib/common.sh`, sabe que `NAME`, `VERSION`, `PREFIXES` y `USAGE` se usan, y desaparecen los 52 `SC2034`.

Va en un fichero, y no como opciones del script, para que el shellcheck de un editor dé lo mismo que el script y el CI.

### 4. Los dos avisos de hoy: silenciados con su motivo

Los dos `SC2001` de `components/gcc-mingw.sh` sangran con `sed 's/^/  /'` cada línea de un texto de varias (la lista de DLLs y la salida del programa de prueba). La alternativa de shellcheck, `${var//search/replace}`, no tiene ancla por línea: haría falta `"  ${var//$'\n'/$'\n  '}"`, que es más difícil de leer. Se silencian en su línea:

```bash
# shellcheck disable=SC2001 # indents every line of a multi-line text
```

Regla para lo que venga: un aviso se corrige; si se silencia, es en su línea y con el motivo al lado. Nunca en `.shellcheckrc`.

### 5. Documentación

- **AGENTS.md:** en Verification, que el CI pasa shellcheck y que `scripts/check-scripts.sh` se ejecuta antes de cada commit que toque un script, y la regla de la decisión 4; en Local environment, que shellcheck no hace falta instalarlo; en Repository layout, el script nuevo y `.shellcheckrc`.
- **`docs/toolchain.md`:** una sección corta sobre la comprobación de los scripts, dentro de las convenciones (§1).
- **README:** nada; no cambia nada para quien usa el toolchain. Tampoco el CHANGELOG.

## Risks / Trade-offs

- [El paso del CI descarga 2,5 MB de GitHub en cada ejecución] → El trabajo `Version and scripts` no tiene caché, y añadirla costaría más que la descarga. Si la descarga falla, el CI falla: es la misma dependencia de GitHub que ya tiene `actions/checkout`.
- [Una versión fijada se queda atrás] → Subirla es deliberado, en su propio change, como las versiones de los componentes.
- [shellcheck no ve todo] → No sustituye la instalación de prueba del CI ni las verificaciones de cada change. Es una red más barata para los errores de shell.
- [Avisos silenciados que se acumulan] → Cada uno lleva su motivo en la línea, y `grep 'shellcheck disable'` los lista.
