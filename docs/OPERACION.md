# Operación

## Credenciales de claude.ai

Es el único paso que exige a una persona con navegador, y se hace fuera del clúster:

```bash
make credenciales           # docker run -it ... login
```

El script abre el flujo de `claude auth login` dentro del contenedor, imprime la URL, tú pegas el
código y saca el fichero a `.credenciales/credentials.json`. Después:

```bash
kubectl -n agentes create secret generic agente-pod-credenciales \
  --from-file=credentials.json=.credenciales/credentials.json \
  --dry-run=client -o yaml | kubectl apply -f -
```

Ese fichero es **semilla**: el pod lo copia al volumen la primera vez y a partir de ahí Claude Code
renueva el token solo, sobre el PVC. Cambiar el Secret después no afecta a un pod que ya arrancó
(salvo que borres su PVC).

### Varios agentes con la misma cuenta

Todos los pods pueden compartir `credentials.json`, pero comparten también el token de refresco: si
uno lo renueva, los demás pueden encontrarse con el anterior invalidado y tener que reconectar. Es
molesto, no fatal. Si vas a tener varios agentes de forma permanente, dale a cada uno su cuenta:

```bash
./bin/credenciales.sh credentials-0.json
./bin/credenciales.sh credentials-1.json
kubectl -n agentes create secret generic agente-pod-credenciales \
  --from-file=credentials-0.json --from-file=credentials-1.json \
  --dry-run=client -o yaml | kubectl apply -f -
```

Cada pod busca primero `credentials-<ordinal>.json` y, si no está, cae en `credentials.json`.

## Escalar

```bash
make escalar AGENTES=3      # actualiza el ConfigMap y el StatefulSet
```

Cada agente nuevo estrena PVC y sesión. Al bajar el número, Kubernetes borra los pods de arriba
pero **conserva sus PVC**: si vuelves a subir, retoman su estado.

## Ver qué está pasando

```bash
make estado                 # pods, PVC y eventos
make urls                   # enlace de cada sesión
make logs POD=agente-pod-1  # salida del agente
```

Los logs del pod son literalmente lo que se ve en la terminal del agente (la sesión de tmux
redirigida a stdout), así que ahí aparece la URL de la sesión y los reintentos de conexión.

## Actualizar la versión de Claude Code

Está fijada en el `Dockerfile` (`CLAUDE_VERSION`) y el auto-actualizador viene apagado, para que la
imagen sea reproducible. Para subir de versión: cambia el ARG, `make publicar TAG=...`, actualiza
el tag en `k8s/kustomization.yaml` y `make desplegar`.

## Cuando algo va mal

| Síntoma | Causa habitual |
|---|---|
| `CrashLoopBackOff` y en los logs `no hay credenciales de claude.ai` | Falta el Secret `agente-pod-credenciales` o la clave no coincide |
| `Remote Control requires a full-scope login token` | Las credenciales salieron de `claude setup-token` o de una API key; regenéralas con `make credenciales` |
| El pod está `Running` pero nunca `Ready` | No llega a conectar: mira egress 443 en la NetworkPolicy y que el clúster tenga salida a `api.anthropic.com` |
| La sesión aparece pero no responde | El proceso murió y el bucle lo está relanzando; míralo en `make logs` |
| `403` al desplegar algo | El RoleBinding solo cubre su namespace; copia `k8s/11-rbac.yaml` para el namespace destino |

Diagnóstico completo sin entrar al pod:

```bash
make diagnostico            # versiones, claude doctor y 'kubectl auth can-i' con su ServiceAccount
```
