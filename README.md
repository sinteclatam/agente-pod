# agente-pod

Un agente de Claude Code viviendo dentro de Kubernetes, dedicado a desplegar en Kubernetes.
Se maneja **solo desde Claude Remote Control** —claude.ai/code o la app móvil— porque en el pod
no hay shell para nadie: ni SSH, ni `kubectl exec`.

Es el mismo patrón que ya corre en el VPS de Sinteclatam, pero llevado a un pod: imagen inmutable,
usuario sin privilegios, volumen persistente para que una reinicio no se lleve por delante la
conversación, y permisos de clúster acotados a desplegar.

```
   claude.ai/code ─────► API de Anthropic ◄──── (HTTPS saliente, sin puertos abiertos)
                                                     │
                                              ┌──────┴───────┐
                                              │  agente-pod-0│  tmux + claude remote-control
                                              │  agente-pod-1│  kubectl · helm · git · gh
                                              └──────┬───────┘
                                                     │  ServiceAccount con permisos de despliegue
                                                     ▼
                                              el resto del clúster
```

## Cómo está armado

| Pieza | Para qué |
|---|---|
| `imagen/Dockerfile` | Debian slim + Claude Code (versión fijada) + `kubectl`, `helm`, `yq`, `gh`, `git`, `tmux`. Sin Docker dentro: los builds son cosa de CI |
| `imagen/bin/entrypoint.sh` | Despacha el comando de arranque (`agente`, `login`, `diagnostico`, o lo que le pases) |
| `imagen/bin/bucle.sh` | Mantiene viva la sesión y la **retoma con `--continue`** tras un reinicio |
| `k8s/31-statefulset.yaml` | Un pod por agente, cada uno con su PVC y su nombre de sesión estable |
| `k8s/11-rbac.yaml` | Puede desplegar; **no** puede `pods/exec`, `attach` ni `port-forward` |
| `k8s/41-admision-sin-exec.yaml` | El API server rechaza cualquier intento de shell en el namespace |
| `k8s/40-networkpolicy.yaml` | Nada entrante; saliente solo DNS, 443 y el API server |

## Requisitos

- Kubernetes **1.30+** (la política de admisión usa `ValidatingAdmissionPolicy` v1) con una
  `StorageClass` por defecto para los PVC.
- Una suscripción de claude.ai **Pro, Max, Team o Enterprise**. Remote Control no funciona con
  `ANTHROPIC_API_KEY` ni con el token de `claude setup-token`: esos solo sirven para pedirle
  cosas al modelo, no para abrir sesión remota.
- Un token de GitHub con acceso a los repos de la organización.
- `docker` en tu máquina, solo para el login inicial y para construir la imagen.

## Arranque

```bash
# 1. Imagen (o deja que la publique el workflow de GitHub Actions)
make publicar TAG=v1

# 2. Login de claude.ai: abre una URL, pegas el código, sale el fichero de credenciales
make credenciales

# 3. Namespace y secretos
kubectl apply -f k8s/00-namespace.yaml
kubectl -n agentes create secret generic agente-pod-credenciales \
  --from-file=credentials.json=.credenciales/credentials.json
kubectl -n agentes create secret generic agente-pod-tokens \
  --from-literal=GH_TOKEN=ghp_xxxxx

# 4. Cuántos agentes quieres
vim k8s/20-configmap.yaml     # AGENTES: "3"

# 5. Adelante
make desplegar
make urls                     # un enlace de claude.ai por agente
```

Cada agente aparece en la lista de sesiones de claude.ai con el nombre de su pod
(`agente-pod-0`, `agente-pod-1`, …). Abres el enlace y le hablas.

## Configuración

`ConfigMap agente-pod-config`:

| Clave | Por defecto | Qué hace |
|---|---|---|
| `AGENTES` | `1` | Número de agentes = réplicas del StatefulSet. `make desplegar` lo aplica |
| `WORKDIR` | `/home/agente/workspace` | Directorio de trabajo, dentro del volumen |
| `MODO_PERMISOS` | `bypassPermissions` | Modo de permisos de Claude Code |
| `MODO_SESION` | `continua` | `continua`: una sesión por pod que se retoma al reiniciar. `servidor`: un proceso con varias sesiones (`SESIONES_MAX`), pero sin retomar |
| `SESIONES_MAX` | `1` | Sesiones concurrentes en modo `servidor` |
| `ESPERA_REINTENTO` | `15` | Segundos antes de relanzar si el proceso muere |
| `GIT_USER_NAME`, `GIT_USER_EMAIL`, `TZ` | | Identidad de los commits y zona horaria |

Secretos (se crean con `kubectl`, nunca en git):

| Secret | Contenido |
|---|---|
| `agente-pod-credenciales` | `credentials.json` del login de claude.ai. Para una cuenta por agente: `credentials-0.json`, `credentials-1.json`… |
| `agente-pod-tokens` | `GH_TOKEN` (y lo que quieras inyectar como variable de entorno) |

## Qué pasa si se reinicia

El pod vuelve sobre el mismo PVC. Ahí están las credenciales renovadas, el `~/.claude` con el
historial y los repos clonados, así que el bucle arranca con `claude remote-control --continue` y
**retoma la sesión que venías trabajando** en lugar de abrir una nueva. Si esa sesión ya no existe
en el servidor, lo detecta y abre una limpia.

Más detalle en [docs/OPERACION.md](docs/OPERACION.md) y [docs/SEGURIDAD.md](docs/SEGURIDAD.md).
