# Tasks

## 1. La comprobación de los scripts

- [x] 1.1 Crear `.shellcheckrc` (decisión 3) y `scripts/check-scripts.sh` (decisiones 1 y 2), y silenciar los dos `SC2001` de `components/gcc-mingw.sh` con su motivo (decisión 4). Verificar:
  - que en el repositorio termina sin error, diciendo cuántos scripts ha comprobado y con qué versión de shellcheck;
  - que el shellcheck del sistema (0.10.0 de EPEL), ejecutado a mano en la raíz sin opciones, como lo haría un editor, tampoco da avisos con el `.shellcheckrc`, y que el script no lo usa por no ser la versión fijada;
  - que con un `SOFTWARE_DIR` vacío de `tmp/` con el 0.10.0 del sistema en el PATH (otra versión), descarga la versión fijada, comprueba su suma y la usa, y que una segunda ejecución no descarga nada;
  - que con un tarball falso con el nombre del de shellcheck en ese `SOFTWARE_DIR`, falla antes de ejecutar nada, nombrando el fichero;
  - que un componente de prueba en `components/` con una variable sin comillas hace fallar la comprobación nombrando el script, la línea y el código del aviso, y que un error de sintaxis la hace fallar nombrando el script. Después se borran;
  - que con `GITHUB_ACTIONS=true` esos fallos salen también como anotaciones `::error`/`::warning` con fichero, línea y columna.
- [x] 1.2 Sustituir en `.github/workflows/ci.yml` el paso de sintaxis por `scripts/check-scripts.sh` (decisión 1), y actualizar el comentario de cabecera del workflow. Verificar que el YAML sigue siendo válido.

## 2. Documentación

- [x] 2.1 Documentar la comprobación en AGENTS.md (Verification, Local environment y Repository layout) y en `docs/toolchain.md` (§1), según la decisión 5. Verificar que coincide con el script y el workflow.

## 3. Verificación

- [ ] 3.1 El usuario hace push de la rama y el CI pasa, con el paso `Check the scripts` usando shellcheck 0.11.0.
- [ ] 3.2 El usuario revisa el cambio y da el visto bueno.
