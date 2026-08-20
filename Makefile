IMAGEN ?= ghcr.io/sinteclatam/agente-pod
TAG    ?= latest
NS     ?= agentes

.PHONY: ayuda imagen publicar credenciales desplegar escalar estado logs urls diagnostico borrar

ayuda:
	@grep -E '^[a-z-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

imagen: ## Construye la imagen para la arquitectura local (pruebas)
	docker build -t $(IMAGEN):$(TAG) imagen/

publicar: ## Construye y publica la imagen multiarquitectura en GHCR
	docker buildx build --platform linux/amd64,linux/arm64 -t $(IMAGEN):$(TAG) --push imagen/

credenciales: ## Login en claude.ai y volcado del fichero de credenciales
	./bin/credenciales.sh

desplegar: ## Aplica los manifiestos y escala según AGENTES del ConfigMap
	./bin/aplicar.sh

escalar: ## Cambia el número de agentes: make escalar AGENTES=3
	kubectl -n $(NS) patch configmap agente-pod-config --type merge -p '{"data":{"AGENTES":"$(AGENTES)"}}'
	kubectl -n $(NS) scale statefulset agente-pod --replicas=$(AGENTES)

estado: ## Pods, PVCs y eventos recientes
	kubectl -n $(NS) get pods,pvc -l app.kubernetes.io/name=agente-pod
	@echo; kubectl -n $(NS) get events --sort-by=.lastTimestamp | tail -15

logs: ## Logs del agente: make logs POD=agente-pod-0
	kubectl -n $(NS) logs -f $(or $(POD),agente-pod-0)

urls: ## Enlaces de las sesiones de Remote Control
	./bin/urls.sh

diagnostico: ## Job puntual que imprime versiones y permisos efectivos
	kubectl -n $(NS) run agente-diagnostico --rm -i --restart=Never \
		--image=$(IMAGEN):$(TAG) --overrides='{"spec":{"serviceAccountName":"agente-pod","securityContext":{"runAsNonRoot":true,"runAsUser":10001,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"d","image":"$(IMAGEN):$(TAG)","args":["diagnostico"],"securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}}]}}'

borrar: ## Borra el despliegue (los PVC con el estado se conservan)
	kubectl delete -k k8s/ --ignore-not-found
