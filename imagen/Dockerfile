# Agente autónomo de despliegue en Kubernetes.
# Se maneja únicamente desde Claude Remote Control: la imagen no expone puertos,
# no trae servidor SSH y corre como usuario sin privilegios.
FROM debian:12-slim

ARG TARGETARCH
ARG CLAUDE_VERSION=2.1.231
ARG KUBECTL_VERSION=v1.36.3
ARG HELM_VERSION=v4.2.4
ARG GH_VERSION=2.97.0
ARG YQ_VERSION=v4.53.4

LABEL org.opencontainers.image.title="agente-pod" \
      org.opencontainers.image.description="Agente Claude Code autónomo para desplegar en Kubernetes" \
      org.opencontainers.image.source="https://github.com/sinteclatam/agente-pod"

# Herramientas mínimas. tmux da la pseudo-terminal que necesita la interfaz de Claude Code;
# tini queda como PID 1 para que las señales de Kubernetes lleguen bien.
RUN apt-get update && apt-get install -y --no-install-recommends \
      bash ca-certificates coreutils curl git jq less procps tini tmux tzdata unzip \
    && rm -rf /var/lib/apt/lists/*

# kubectl, helm, yq y gh: el oficio del agente.
RUN set -eux; \
    curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl"; \
    chmod 0755 /usr/local/bin/kubectl; \
    curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" | tar xz -C /tmp; \
    install -m 0755 "/tmp/linux-${TARGETARCH}/helm" /usr/local/bin/helm; \
    curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${TARGETARCH}.tar.gz" | tar xz -C /tmp; \
    install -m 0755 "/tmp/gh_${GH_VERSION}_linux_${TARGETARCH}/bin/gh" /usr/local/bin/gh; \
    curl -fsSLo /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${TARGETARCH}"; \
    chmod 0755 /usr/local/bin/yq; \
    rm -rf /tmp/linux-* /tmp/gh_*; \
    kubectl version --client=true --output=yaml >/dev/null; helm version --short; gh --version | head -1; yq --version

# Claude Code vive en /opt/claude, FUERA del volumen persistente: la imagen es inmutable y
# el auto-actualizador queda apagado (la versión se cambia reconstruyendo la imagen).
ENV CLAUDE_VERSION=${CLAUDE_VERSION}
RUN set -eux; \
    mkdir -p /opt/claude; \
    HOME=/opt/claude bash -c "curl -fsSL https://claude.ai/install.sh | bash -s ${CLAUDE_VERSION}"; \
    ln -s /opt/claude/.local/bin/claude /usr/local/bin/claude; \
    chmod -R a+rX /opt/claude; \
    rm -f /opt/claude/.claude.json; \
    claude --version

COPY bin/ /opt/agente/bin/
COPY contexto/ /opt/agente/contexto/
RUN chmod 0755 /opt/agente/bin/*.sh

# uid/gid fijos: los manifiestos declaran runAsUser 10001 y fsGroup 10001 sobre el PVC.
RUN groupadd -g 10001 agente \
    && useradd -u 10001 -g 10001 -d /home/agente -s /bin/bash -m agente \
    && chown -R 10001:10001 /home/agente

ENV HOME=/home/agente \
    SHELL=/bin/bash \
    PATH=/usr/local/bin:/usr/bin:/bin \
    DISABLE_AUTOUPDATER=1 \
    XDG_CONFIG_HOME=/home/agente/.config \
    XDG_CACHE_HOME=/home/agente/.cache \
    TMPDIR=/tmp

USER 10001:10001
WORKDIR /home/agente

# La imagen no escucha en ningún puerto: toda la comunicación es HTTPS saliente hacia
# api.anthropic.com. No declaramos EXPOSE a propósito.
ENTRYPOINT ["/usr/bin/tini", "--", "/opt/agente/bin/entrypoint.sh"]
CMD ["agente"]
