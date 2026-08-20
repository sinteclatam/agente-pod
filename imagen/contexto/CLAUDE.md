# Agente de despliegue en Kubernetes

Corres **dentro de un pod del propio clúster**, sin usuario humano en la máquina: la única forma
de hablar contigo es Claude Remote Control (claude.ai/code o la app móvil). Nadie va a entrar por
`kubectl exec` a arreglar lo que dejes a medias — el clúster lo tiene bloqueado a propósito. Así
que **deja rastro de lo que haces** y termina lo que empiezas.

## Dónde estás

| | |
|---|---|
| Usuario | `agente` (uid 10001), sin sudo y sin capacidades de Linux |
| Sistema de ficheros | raíz **de solo lectura**; solo puedes escribir en `$HOME` (volumen persistente) y `/tmp` |
| Estado persistente | `/home/agente` sobrevive reinicios del pod: sesión, credenciales, repos clonados |
| Espacio de trabajo | `/home/agente/workspace` — clona aquí los repos |
| Herramientas | `kubectl`, `helm`, `yq`, `jq`, `git`, `gh`, `tmux` |
| Red | solo salida HTTPS y el API server. No hay Docker: **no puedes construir imágenes aquí** |

Los builds de imágenes se hacen en CI (GitHub Actions), no en el pod. Si un despliegue necesita
una imagen nueva, dispara o arregla el workflow del repo y espera al tag.

## Kubernetes

`kubectl` ya está autenticado con la ServiceAccount del pod; no hay kubeconfig que montar.

```bash
kubectl auth can-i --list                 # lo primero cuando algo dé 403
kubectl -n <ns> get all
kubectl -n <ns> rollout status deploy/<nombre> --timeout=180s
```

Tu rol de despliegue **no incluye** `pods/exec`, `pods/attach` ni `pods/portforward`: es
deliberado, no es un error de configuración. Para depurar usa `logs`, `describe` y `events`.

Reglas de la casa:

1. **Primero `--dry-run=server`**, después de verdad. En Helm, `helm diff` o `--dry-run`.
2. La fuente de la verdad es el repo, no el clúster. Si cambias algo a mano para salir del paso,
   dilo y súbelo al repo en el mismo turno.
3. **Nunca** borres namespaces, PVCs, StatefulSets con datos ni Secrets sin pedir confirmación
   explícita. Borrar un PVC es borrar datos de producción.
4. `kubectl delete` de golpe sobre un selector amplio: no. Nombra los recursos.
5. Después de aplicar, **verifica**: `rollout status`, pods en `Running`/`Ready`, y los eventos
   del namespace. Un `apply` que devuelve `configured` no significa que la app arrancó.
6. Si vas a tocar el propio StatefulSet `agente-pod`, recuerda que eres tú: un `rollout restart`
   te mata la sesión (volverás, pero la conversación se corta).

## GitHub

`gh` está autenticado con un token de la organización y git usa `gh` como credential helper, así
que `clone`/`push` funcionan sin pedir nada.

```bash
gh repo list <organizacion> --limit 100
gh pr create --fill
```

Trabaja en ramas y abre PR salvo que te pidan lo contrario. No subas secretos: los tokens llegan
por variables de entorno y por `/secretos`, y **no deben aparecer en ningún commit, log ni
respuesta**.

## Si algo se rompe

Tu propio proceso lo relanza `bin/bucle.sh` y, si el pod muere, Kubernetes lo reinicia sobre el
mismo volumen y retomas la sesión anterior. No hace falta que "te reinicies" a mano.
