# 12. Kubernetes Dashboard via GitOps

> **Antes de começar:** todos os comandos a seguir devem ser executados **no servidor Debian** (a menos que indicado outro local).

Este capítulo documenta a instalação do **Kubernetes Dashboard** de forma 100% declarativa, gerenciado pelo Argo CD. Será a primeira aplicação em um diretório dedicado (`infrastructure/`), definindo o padrão de pastas para futuros componentes.

---

## 12.1. Pré-requisitos

- Argo CD instalado e operacional (Capítulo 10).
- CLI do Argo CD configurada com login e registro do cluster.
- Acesso ao repositório `homelab` no GitHub.

---

## 12.2. Estrutura de pastas

```
homelab/
├── argocd/
│   ├── root-app.yaml                                    # App of Apps (já existente)
│   ├── applications/
│   │   ├── argocd-ingress.yaml                          # IngressRoute do ArgoCD (já existente)
│   │   ├── web-server-argocd-application.yaml           # nginx (já existente)
│   │   ├── homelab-project-app.yaml                     # NOVA — gerencia o AppProject
│   │   └── kubernetes-dashboard-argocd-application.yaml # NOVA — gerencia o Dashboard
│   └── projects/
│       └── homelab-project.yaml                         # ATUALIZADO — whitelist RBAC
├── infrastructure/
│   └── dashboard/
│       ├── namespace.yaml                               # Namespace kubernetes-dashboard
│       ├── dashboard.yaml                               # Manifestos oficiais v2.7.0
│       ├── sa-admin.yaml                                # ServiceAccount admin-user
│       ├── clusterrolebinding-admin.yaml                # ClusterRoleBinding admin-user → cluster-admin
│       ├── serverstransport.yaml                        # ServersTransport (insecureSkipVerify)
│       └── ingressroute.yaml                            # IngressRoute (TLS + Host)
```

---

## 12.3. Arquivos novos

### 12.3.1. AppProject (`argocd/projects/homelab-project.yaml`)

**Objetivo:** Liberar recursos RBAC cluster-scoped para que o ArgoCD possa criar ClusterRole e ClusterRoleBinding.

Adicionar ao `clusterResourceWhitelist`:

```yaml
- group: 'rbac.authorization.k8s.io'
  kind: 'ClusterRole'
- group: 'rbac.authorization.k8s.io'
  kind: 'ClusterRoleBinding'
```

### 12.3.2. Application do AppProject (`argocd/applications/homelab-project-app.yaml`)

**Objetivo:** Application que vigia `argocd/projects/` e aplica o AppProject. Torna o AppProject GitOps (sem `kubectl apply` manual).

Segue o padrão do `web-server-argocd-application.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: homelab-project-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: homelab
  source:
    repoURL: https://github.com/joao-calado/homelab.git
    targetRevision: main
    path: argocd/projects
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### 12.3.3. Application do Dashboard (`argocd/applications/kubernetes-dashboard-argocd-application.yaml`)

**Objetivo:** Application que vigia `infrastructure/dashboard/` e deploya o Dashboard.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kubernetes-dashboard-argocd-application
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: homelab
  source:
    repoURL: https://github.com/joao-calado/homelab.git
    targetRevision: main
    path: infrastructure/dashboard
  destination:
    server: https://kubernetes.default.svc
    namespace: kubernetes-dashboard
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### 12.3.4. Namespace (`infrastructure/dashboard/namespace.yaml`)

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: kubernetes-dashboard
```

### 12.3.5. Manifestos oficiais (`infrastructure/dashboard/dashboard.yaml`)

Manifestos oficiais do Dashboard v2.7.0, obtidos de:

```
https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
```

O bloco `Namespace` foi removido (mantido em `namespace.yaml`). Recursos incluídos: ServiceAccount, Service, Secrets, ConfigMap, Role, ClusterRole, RoleBinding, ClusterRoleBinding, 2 Deployments (dashboard + metrics-scraper), 2 Services.

### 12.3.6. ServiceAccount admin-user (`infrastructure/dashboard/sa-admin.yaml`)

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
```

### 12.3.7. ClusterRoleBinding admin-user (`infrastructure/dashboard/clusterrolebinding-admin.yaml`)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: admin-user
    namespace: kubernetes-dashboard
```

### 12.3.8. ServersTransport (`infrastructure/dashboard/serverstransport.yaml`)

Informa ao Traefik para ignorar o certificado autoassinado do backend do Dashboard (HTTPS:8443).

```yaml
apiVersion: traefik.io/v1alpha1
kind: ServersTransport
metadata:
  name: dashboard-insecure
  namespace: kubernetes-dashboard
spec:
  insecureSkipVerify: true
```

### 12.3.9. IngressRoute (`infrastructure/dashboard/ingressroute.yaml`)

Expõe o Dashboard em `https://dashboard.192.168.1.200.nip.io` com TLS.

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`dashboard.192.168.1.200.nip.io`)
      kind: Rule
      services:
        - name: kubernetes-dashboard
          port: 443
          serversTransport: dashboard-insecure
  tls:
    secretName: dashboard-tls
```

> **Nota:** a porta **443** é a porta do Service (que mapeia para 8443 no container). Traefik assume esquema HTTPS automaticamente pela porta 443.

---

## 12.4. Fluxo de sincronização do ArgoCD

Após o merge na `main`, o fluxo automático é:

1. Root-app reconcilia → lê `argocd/applications/` → cria `homelab-project-app` e `kubernetes-dashboard-argocd-application`
2. `homelab-project-app` synca → aplica o AppProject com RBAC atualizado
3. `kubernetes-dashboard-argocd-application` synca → deploya todos os recursos de `infrastructure/dashboard/`
4. Usuário cria o Secret TLS (único passo manual fora do Git)

---

## 12.5. Secret TLS (fora do Git)

O Secret `dashboard-tls` contém chave privada e não pode ir para o repositório. É criado uma vez via `openssl` + `kubectl create secret tls`.

```bash
openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -subj "/CN=dashboard.192.168.1.200.nip.io" \
  -keyout /tmp/dashboard-tls.key -out /tmp/dashboard-tls.crt
kubectl create secret tls dashboard-tls -n kubernetes-dashboard \
  --cert=/tmp/dashboard-tls.crt --key=/tmp/dashboard-tls.key
rm /tmp/dashboard-tls.crt /tmp/dashboard-tls.key
```

> **Nota:** o padrão é o mesmo já usado para `argocd-tls` (documentado no Capítulo 10).

---

## 12.6. Validação

1. Verificar que o ArgoCD sincronizou:

```bash
argocd app list
argocd app get kubernetes-dashboard-argocd-application
```

2. Ver pods e serviços:

```bash
kubectl get pods,svc,ingressroute -n kubernetes-dashboard
```

Saída esperada:

```text
NAME                                             READY   STATUS    RESTARTS   AGE
pod/kubernetes-dashboard-xxxxx-yyyyy             1/1     Running   0          2m
pod/dashboard-metrics-scraper-xxxxx-yyyyy        1/1     Running   0          2m

NAME                              TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/kubernetes-dashboard      ClusterIP   10.43.xxx.xx   <none>        443/TCP   2m
service/dashboard-metrics-scraper ClusterIP   10.43.xxx.xx   <none>        8000/TCP  2m

NAME                                                 AGE
ingressroute.traefik.io/kubernetes-dashboard          2m
```

3. Testar acesso via curl:

```bash
curl -kv https://dashboard.192.168.1.200.nip.io
```

4. Gerar token de acesso:

```bash
kubectl -n kubernetes-dashboard create token admin-user --duration=8760h
```

> **Nota:** a duração pode ser truncada pelo apiserver (`--service-account-max-token-expiration`). Verifique com `kubectl create token admin-user --duration=87600h` — se retornar menos, use o valor retornado.

---

## 12.7. Login

1. Acesse `https://dashboard.192.168.1.200.nip.io` no navegador.
2. Aceite o certificado autoassinado.
3. Selecione **Token** como método de autenticação.
4. Cole o token obtido no passo anterior.
5. Clique em **Sign in**.

O Dashboard mostra todos os recursos do cluster (pods, services, deployments, etc.).

---

## 12.8. Diagnóstico

### Application não sincroniza

```bash
argocd app get kubernetes-dashboard-argocd-application
argocd app sync kubernetes-dashboard-argocd-application
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=50
```

### Pods em Pending ou CrashLoopBackOff

```bash
kubectl describe pod -n kubernetes-dashboard -l app=kubernetes-dashboard
kubectl logs -n kubernetes-dashboard -l app=kubernetes-dashboard --tail=50
```

### IngressRoute não funciona

```bash
kubectl get ingressroute -n kubernetes-dashboard
kubectl get secret dashboard-tls -n kubernetes-dashboard
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=30
```

### "Permission denied" no Project

```bash
argocd proj get homelab
```

Se faltar permissão para ClusterRole/ClusterRoleBinding, verifique se o `homelab-project-app` sincronizou:

```bash
argocd app get homelab-project-app
argocd app sync homelab-project-app
```

---

## Observação

```text
Este guia foi testado em um notebook com Debian 13, 4 vCPUs, 8 GB RAM e Wi-Fi Realtek. O Kubernetes Dashboard consome aproximadamente 50-100 MiB de RAM. Verifique com kubectl top nodes se há recurso suficiente antes de instalar.
```

---

## ✅ Próximo passo

Com o Dashboard instalado, consulte o estado atual e diagnóstico do cluster:

👉 [11-status-atual.md](11-status-atual.md)
