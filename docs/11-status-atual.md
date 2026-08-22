# 11. Estado atual e diagnóstico rápido

Este capítulo descreve o **estado esperado** do cluster após seguir todos os passos anteriores (incluindo a instalação do Argo CD) e fornece um roteiro de diagnóstico para quando algo falha.

> **Nota:** Os endereços IP e nomes de interface aqui utilizados são exemplos (`192.168.1.200`, `wlp3s0`). Substitua pelos valores da sua própria rede.

---

## 11.1. Nós e recursos alocáveis

1. Comando:

```sh
kubectl get nodes
```

Saída esperada:

```text
NAME          STATUS   ROLES                  AGE   VERSION
k3s-master    Ready    control-plane,master   1d    v1.32.2+k3s1
```

2. Ver recursos alocáveis (após as reservas `system-reserved` e `kube-reserved`):

```sh
kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU_ALLOC:.status.allocatable.cpu,MEM_ALLOC:.status.allocatable.memory
```

Exemplo:

```text
NAME          CPU_ALLOC   MEM_ALLOC
k3s-master    1950m       5620Mi
```

Descrição:

```text
O nó está "Ready". CPU, memória e pods alocáveis são os valores que o kubelet pode reservar (total do nó menos as reservas definidas em --kubelet-arg). O limite de pods (ex.: 50) define quantos podem ser executados simultaneamente no nó.
```

---

## 11.2. Pods do sistema (namespace `kube-system`)

1. Comando para listar:

```sh
kubectl get pods -n kube-system
```

2. Tabela descritiva de cada pod:

```text
coredns-*: DNS interno do cluster (IP fixo 10.43.0.10). Essencial para resolução de nomes entre serviços.
local-path-provisioner-*: Provisionador de volumes locais. Cria PersistentVolumes a partir do disco do nó.
metrics-server-*: Coleta métricas de CPU/memória para kubectl top e HPA.
svclb-traefik-*: Load balancer simples do K3s. Escuta nas portas 80 e 443 do nó e encaminha para o Traefik.
traefik-*: Ingress controller. Lê os recursos Ingress e roteia as requisições HTTP/S para os serviços backend.
helm-install-traefik-*: Pod temporário (Completed) que instalou o Traefik via Helm. Pode ser removido com segurança.

3. Pods do Argo CD (namespace `argocd`):

```sh
kubectl get pods -n argocd
```

```text
argocd-application-controller-*: Controlador principal. Garante que o estado do cluster corresponda ao Git (sincronização).
argocd-applicationset-controller-*: Gera Applications a partir de templates (ApplicationSets).
argocd-dex-server-*: Provedor de autenticação OIDC/SSO integrado. Opcional para homelab.
argocd-notifications-controller-*: Envia notificações sobre sincronizações e mudanças de estado.
argocd-redis-*: Cache do Argo CD (estado das Applications, sessões, repo).
argocd-repo-server-*: Cache local do repositório Git. Clona e mantém o repositório sincronizado.
argocd-server-*: Servidor HTTP/HTTPS (UI + API). Exposto via IngressRoute com TLS.
```

---

## 11.3. Pods da aplicação (namespace `default`)

1. Comando:

```sh
kubectl get pods -l app=nginx-teste
```

Saída esperada:

```text
NAME                           READY   STATUS    RESTARTS   AGE
web-server-xxxxx-yyyyy         1/1     Running   0          1h
web-server-xxxxx-zzzzz         1/1     Running   0          1h
```

---

## 11.4. Fluxo de uma requisição externa

```text
Navegador (cliente)
       │
       │ HTTP GET / → http://nginx.192.168.1.200.nip.io
       ▼
   Notebook (porta 80 – escutada pelo svclb-traefik)
       │
       │ iptables redireciona para o pod svclb-traefik
       ▼
   Pod svclb-traefik (namespace kube-system)
       │
       │ Encaminha para o Service do Traefik (ClusterIP)
       ▼
   Pod traefik (namespace kube-system)
       │
       │ Lê as regras do Ingress web-ingress (host: nginx.192.168.1.200.nip.io)
       ▼
   Service web-service (ClusterIP, porta 80, namespace default)
       │
       │ Balanceamento round‑robin entre os pods web-server
       ▼
   Pod web-server-xxxxx-yyyyy (ou o outro)
       │
       │ Resposta HTML com cabeçalhos anti‑cache e X-Pod-Name
       ▼
   Navegador – exibe a página e mostra qual pod respondeu
```

---

## 11.5. Diagnóstico rápido (ordem sugerida)

Siga os passos abaixo para identificar a causa de problemas.

### 1. Conectividade Wi‑Fi

```sh
ping 192.168.1.1
```

Se falhar, verifique os logs do watchdog:

```sh
journalctl -t wifi-watchdog -n 10
```

### 2. Logs do K3s

```sh
journalctl -u k3s -f --lines=50
```

Procure por mensagens como `failed to start`, `nameserver limits`, `failed to sync`, `connection refused`.

### 3. Estado dos pods

```sh
kubectl get pods -A
```

Pods com `CrashLoopBackOff`, `ImagePullBackOff`, `Pending` ou `Error`.

### 4. Eventos do cluster

```sh
kubectl get events -A --sort-by='.lastTimestamp'
```

Os eventos mais recentes aparecem por último. Veja se há `FailedScheduling`, `FailedMount`, `Unhealthy`, etc.

### 5. Ingress / Traefik

```sh
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=20
```

### 6. DNS interno do cluster

```sh
kubectl run -it --rm test-dns --image=busybox:1.28 --restart=Never -- nslookup kubernetes.default
```

Se não resolver, reveja o capítulo 4 (ajustes de DNS) e confirme que o host só tem um servidor DNS (`192.168.1.1`).

### 7. Recurso do nó (CPU/memória)

```sh
kubectl top nodes
kubectl top pods -A
```

Se muitos pods estiverem em `Pending` com eventos de `Insufficient memory`, `Insufficient cpu` ou `Too many pods`, verifique o limite de pods do nó com `kubectl describe node | grep pods`. Se o valor for igual ao número de pods existentes, aumente o `max-pods` no serviço do K3s (consulte o Capítulo 3). Reduza as reservas se for falta de CPU/memória.

---

## 11.6. Arquitetura do cluster K3s (fluxo da requisição)
```mermaid
graph LR
    User((Usuário)) -->|HTTP GET nginx.192.168.1.200.nip.io| LB["svclb-traefik\n(pod, porta 80/443)"]
    LB -->|encaminha| Traefik["Traefik pod\n(Ingress controller)"]
    Traefik -->|lê regras do Ingress| Ingress[Ingress web-ingress]
    Ingress -->|roteia para| SVC["Service web-service\n(ClusterIP)"]
    SVC -->|balanceamento round-robin| Pod1[Pod web-server-1]
    SVC -->|balanceamento round-robin| Pod2[Pod web-server-2]
    Pod1 -->|resposta com cabeçalhos anti-cache| User
    Pod2 -->|resposta com cabeçalhos anti-cache| User
```

---

## 11.7. Diagnóstico do Argo CD

### Applications não sincronizam

```sh
argocd app list                           # Ver status de todas as Applications
argocd app get web-server-argocd-application     # Ver detalhes + erros
argocd app sync web-server-argocd-application    # Forçar sincronização manual
```

### Pods do Argo CD com problema

```sh
kubectl get pods -n argocd                                   # Estado dos pods
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=30
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=30
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server --tail=30
```

### IngressRoute do Argo CD (argocd.192.168.1.200.nip.io)

```sh
kubectl get ingressroute -n argocd         # Ver se a rota existe
kubectl get secret argocd-tls -n argocd    # Ver se o certificado TLS existe
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=30  # Logs do Traefik
```

### Recursos do nó baixos para o Argo CD

```sh
kubectl top pods -n argocd           # Consumo atual
kubectl top nodes                    # Recursos totais do nó
```

Se pods do Argo CD estiverem `Pending` por `Insufficient memory`, considere reduzir reservas do K3s ou aumentar recursos do nó.

---

## Observação

```text
Este guia foi testado em um notebook com Debian 13, 4 vCPUs, 8 GB RAM e Wi-Fi Realtek. Os sintomas e soluções podem variar conforme o hardware, mas os conceitos apresentados (anti‑cache, watchdog, reservas de recursos) são universais.
```

---

## 🚀 Próximos passos

Você concluiu a configuração do homelab com **GitOps via Argo CD**! Os projetos futuros incluem:

**1. StockMemo – Gestor de Inventário e Ordens de Serviço**  
Aplicação Ruby on Rails para pequenas oficinas (clientes/equipamentos, controle de peças, cálculo de markup, histórico OS, PDF, auditoria).

**2. Pipeline CI/CD com GitHub Actions**  
Automação: push → build Docker → Docker Hub → deploy automático no K3s via Argo CD.

**3. Stack de observabilidade (Prometheus + Loki + Grafana)**  
Métricas do cluster, logs centralizados e dashboards unificados.

**Obrigado por seguir este guia!**
