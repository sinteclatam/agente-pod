# Seguridad

El agente trabaja con `bypassPermissions`: no pide permiso antes de ejecutar. Eso lo hace útil y,
a la vez, obliga a que la caja donde vive sea estrecha. Esto es lo que hay y —tan importante como
eso— lo que **no** hay.

## Nadie entra por shell

Tres capas, en orden de quién las puede saltar:

1. **La imagen**: no lleva servidor SSH, no expone puertos y corre como uid 10001 sin capacidades.
2. **RBAC**: el rol del agente no incluye `pods/exec`, `pods/attach` ni `pods/portforward`, así
   que ni él mismo puede abrirse una shell en otro pod.
3. **Admisión** (`k8s/41-admision-sin-exec.yaml`): una `ValidatingAdmissionPolicy` niega las
   operaciones `CONNECT` sobre `pods/exec`, `attach` y `portforward` en todo el namespace. Esto
   sí frena a un administrador con permisos de sobra.

**El límite honesto**: quien pueda editar `ValidatingAdmissionPolicy` o tenga acceso al nodo
(kubelet, containerd, disco) puede entrar de todas formas. Un contenedor no se puede blindar
contra el administrador del clúster que lo ejecuta. Si eso importa, el control va en el IAM del
proveedor y en la auditoría, no aquí.

## Superficie del contenedor

- Raíz de solo lectura; solo se escribe en el PVC (`/home/agente`) y en `/tmp` (emptyDir, 2 Gi).
- `allowPrivilegeEscalation: false`, `capabilities: drop: [ALL]`, `seccompProfile: RuntimeDefault`.
- El namespace va con Pod Security Admission en `restricted`: aunque el agente puede crear pods
  ahí, el API server rechaza los que pidan privilegios, root o namespaces del host.
- NetworkPolicy: sin tráfico entrante; de salida, DNS, 443 y el API server, con los metadatos de
  la nube (`169.254.169.254`) excluidos para que no se puedan pedir credenciales de la instancia.

## Secretos

- El token de GitHub y las credenciales de claude.ai van en `Secret`, no en el `ConfigMap`: un
  ConfigMap se lee con cualquier permiso de lectura del namespace y aparece entero en un
  `kubectl get -o yaml`. Los ficheros de `/secretos` se montan en solo lectura y con modo `0400`.
- Las credenciales renovadas viven en el PVC. **Borrar el PVC es cerrar sesión**: hay que volver a
  sembrar el Secret.
- `.gitignore` excluye `.credenciales/`. Si un token se filtra, revócalo en GitHub y en
  claude.ai/settings; rotar es más barato que auditar.

## Alcance en el clúster

Por defecto el agente solo puede desplegar en su propio namespace (`agentes`). Darle otro es
copiar el `RoleBinding` con el namespace destino: el alcance queda escrito en el repo y se revisa
en un PR, en vez de vivir en la cabeza de alguien.

No se le concede `rbac.authorization.k8s.io` a propósito: sin poder crear `Role`s ni
`RoleBinding`s no puede ampliarse los permisos a sí mismo.

## Lo que conviene tener claro

Quien tenga tu sesión de claude.ai puede darle órdenes al agente, y el agente puede desplegar en el
clúster. La cuenta que hace `make credenciales` es, en la práctica, una credencial de despliegue:
protégela con 2FA y no la compartas.
