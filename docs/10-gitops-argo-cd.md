# 10. GitOps com Argo CD

> **Antes de começar:** todos os comandos a seguir devem ser executados **no servidor Debian** (a menos que indicado outro local).

Este capítulo documenta a instalação do **Argo CD**, a criação do padrão **App of Apps** e a exposição da UI com **TLS via Traefik**. Após este capítulo, todo deploy será feito exclusivamente via Git.

---

## 10.1. Instalar o Argo CD

1. Pré-verificação: o limite de pods do nó deve ser >= 20:

```sh
kubectl describe node | grep pods
```

Saída esperada:

```text
pods:               50
```

Se o valor for `10`, será necessário aumentá-lo antes de prosseguir (consulte o Capítulo 3 para instruções).

2. Criar namespace e aplicar manifesto oficial com `--server-side`:

```sh
kubectl create namespace argocd
kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

> `--server-side` é necessário porque o CRD `ApplicationSet` tem schema grande demais para o client-side apply padrão (limite etcd de 256KB).

3. Aguardar todos os pods ficarem `Running`:

```sh
kubectl wait --for=condition=Ready pods -n argocd --all --timeout=300s
```

Saída esperada: número variável de pods (tipicamente 6-8) no namespace `argocd` com status `Running`.

4. Verificar a versão instalada:

```sh
kubectl -n argocd get deploy argocd-server -o jsonpath="{.spec.template.spec.containers[0].image}{'\n'}"
```

Saída esperada (exemplo):
```text
quay.io/argoproj/argocd:v2.14.0
```

5. Habilitar modo `--insecure` no servidor (necessário para CLI via Traefik):

```sh
kubectl patch deployment argocd-server -n argocd \
  --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--insecure"}]'
kubectl rollout status deployment argocd-server -n argocd
```

---

## 10.2. Clonar o repositório no servidor

No servidor Debian, clone o repositório `homelab` para acessar os manifestos:

```sh
cd ~
git clone https://github.com/joao-calado/homelab.git
cd homelab
```

> Se você já desenvolve localmente e envia para o GitHub, faça `git pull` para garantir a versão mais recente.

---

## 10.3. Criar a estrutura App of Apps

**App of Apps** é um padrão onde uma Application "pai" (root-app) aponta para um diretório contendo manifests de outras Applications "filhas". Ao sincronizar a root-app, o Argo CD cria automaticamente todas as filhas. Isso permite adicionar novas Applications fazendo apenas commit de um YAML no diretório — sem jamais precisar reaplicar o bootstrap manual.

> **Nota:** os arquivos abaixo já estão versionados no repositório. Ao clonar em 10.3, você já os tem disponíveis — nenhuma ação manual de criação é necessária.

Dentro do diretório `~/homelab`, a estrutura abaixo define os arquivos que o Argo CD usará para gerenciar tudo:

```
homelab/
├── argocd/
│   ├── applications/
│   │   ├── argocd-ingress.yaml                          # IngressRoute (Secret criado manualmente)
│   │   ├── homelab-project-app.yaml                     # Application → projects/ → AppProject
│   │   ├── kubernetes-dashboard-argocd-application.yaml # Application → infrastructure/dashboard/
│   │   └── web-server-argocd-application.yaml           # Application → manifests/ → ns default
│   ├── projects/
│   │   └── homelab-project.yaml                         # Permissões (repositórios, CRDs Traefik, RBAC)
│   └── root-app.yaml                                   # Application of Applications (bootstrap)
├── infrastructure/
│   └── dashboard/                                       # Kubernetes Dashboard (GitOps)
└── manifests/
    └── app.yaml                                         # Deployment (replicas:2) + Service + Ingress
```

### 10.3.1. AppProject (`argocd/projects/homelab-project.yaml`)

Define quais repositórios, namespaces e tipos de recurso são permitidos:

```sh
kubectl apply -f argocd/projects/homelab-project.yaml
```

### 10.3.2. Argo CD Ingress (`argocd/applications/argocd-ingress.yaml`)

Gere o certificado TLS e crie o Secret **manualmente** (não versionado):

```sh
openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -subj "/CN=argocd.192.168.1.200.nip.io" \
  -keyout /tmp/argocd-tls.key -out /tmp/argocd-tls.crt
kubectl create secret tls argocd-tls -n argocd \
  --cert=/tmp/argocd-tls.crt --key=/tmp/argocd-tls.key
rm /tmp/argocd-tls.crt /tmp/argocd-tls.key
```

O arquivo `argocd/applications/argocd-ingress.yaml` (versionado) contém apenas o **IngressRoute** — sem o Secret, que já existe no cluster. O IngressRoute referência o Secret `argocd-tls` na propriedade `tls.secretName`. Veja o arquivo completo em [argocd/applications/argocd-ingress.yaml](../../argocd/applications/argocd-ingress.yaml).

---

### 10.3.3. Root App - App of Apps (`argocd/root-app.yaml`)

Application que gerencia todas as outras Applications na pasta `argocd/applications/`. Ela é o ponto de entrada — aplicada manualmente uma vez.

### 10.3.4. Web Server Application (`argocd/applications/web-server-argocd-application.yaml`)

Application que aponta para a pasta `manifests/` no repositório e aplica os recursos no namespace `default`. Veja o arquivo em [argocd/applications/web-server-argocd-application.yaml](../../argocd/applications/web-server-argocd-application.yaml).

---

## 10.4. Fazer bootstrap da Root App

A Root App é o único recurso aplicado manualmente. Ela criará todo o resto automaticamente.

```sh
kubectl apply -f argocd/root-app.yaml
```

Saída esperada:

```text
application.argoproj.io/root-app created
```

---

## 10.5. Instalar a CLI e registrar o cluster

(O IngressRoute `argocd.192.168.1.200.nip.io` será criado pelo bootstrap — o wait no passo 1 garante que ele está ativo antes de prosseguir.)

### 10.5.1. Por que instalar a CLI?

`argocd cluster add` (via CLI) é o único jeito de conceder permissão ao Argo CD para gerenciar o cluster — a UI não tem função equivalente. O comando cria um ServiceAccount `argocd-manager` com `cluster-admin` e armazena o token no Argo CD. Sem isso, toda Application falha com `"cluster not found"` ou `"permission denied"`. A CLI também serve para diagnóstico rápido (`argocd app get`, `argocd app sync`).

### 10.5.2. Instalar a CLI

```sh
sudo curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo chmod +x /usr/local/bin/argocd
```

### 10.5.3. Login e registrar o cluster

1. Aguardar o IngressRoute ser criado pelo bootstrap:

```sh
until kubectl get ingressroute argocd-server -n argocd &>/dev/null; do sleep 3; done && echo "IngressRoute ativo"
```

2. Obter a senha inicial:

```sh
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

3. Login via nip.io (Ingress já ativo):

```sh
argocd login argocd.192.168.1.200.nip.io --username admin --password '<SENHA>' --insecure
```

4. Registrar o cluster:

```sh
argocd cluster add $(kubectl config current-context) --name in-cluster --kubeconfig /etc/rancher/k3s/k3s.yaml
```

5. Saída esperada:

```text
INFO[0000] Successfully added cluster: in-cluster
```

> Estes comandos executam **no servidor** (a CLI precisa acesso ao kubeconfig local). Depois de registrar o cluster, o navegador no seu PC em `https://argocd.192.168.1.200.nip.io` funciona para tudo (sync, visualizar apps, etc.).

---

## 10.6. Validar tudo

1. Listar Applications (todas devem estar `Synced + Healthy`):

```sh
argocd app list
```

```text
NAME                      CLUSTER                         NAMESPACE  PROJECT  STATUS  HEALTH
argocd-ingress            https://kubernetes.default.svc  argocd     homelab  Synced  Healthy
root-app                  https://kubernetes.default.svc  argocd     homelab  Synced  Healthy
web-server-argocd-application    https://kubernetes.default.svc  default    homelab  Synced  Healthy
```

2. Ver pods da aplicação (namespace `default`):

```sh
kubectl get pods -l app=nginx-teste
```

```text
NAME                           READY   STATUS    RESTARTS   AGE
web-server-xxxxx-yyyyy         1/1     Running   0          1m
```

3. Ver pods do Argo CD (namespace `argocd`):

```sh
kubectl get pods -n argocd
```

4. Testar aplicação nginx:

```sh
curl -H "Host: nginx.192.168.1.200.nip.io" http://192.168.1.200
```

5. Acessar UI do Argo CD via navegador:

- **https://argocd.192.168.1.200.nip.io**
- Login: `admin` / senha obtida no passo 10.5.3
- Aceite o certificado auto-assinado (homelab)

---

## 10.7. Migrar recursos criados manualmente para o GitOps

Recursos que existiam antes do Argo CD (criados com `kubectl apply -f`) precisam ser deletados. O Argo CD recriará tudo a partir do Git com self-heal.

Se o manifesto estava no repositório (`manifests/app.yaml`):

```sh
kubectl delete -f manifests/app.yaml
```

Se o manifesto estava em outro diretório (ex: `~/proj-k3s-app/app.yaml`):

```sh
kubectl delete -f ~/proj-k3s-app/app.yaml
```

Verificar que o self-heal recriou os pods:

```sh
kubectl get pods -l app=nginx-teste
```

> **A partir de agora:** nunca mais use `kubectl apply`. Toda alteração deve ser feita no Git, commitada e enviada.

---

## 10.8. Teste GitOps end-to-end

1. Editar `manifests/app.yaml` localmente, alterando `replicas: 1` para `replicas: 2`.
2. Commitar e enviar:

```sh
git add manifests/app.yaml
git commit -m "chore: Aumenta replicas para 2"
git push origin main
```

3. Aguardar até 60 segundos e verificar:

```sh
kubectl get pods -l app=nginx-teste
```

```text
NAME                           READY   STATUS    RESTARTS   AGE
web-server-xxxxx-yyyyy         1/1     Running   0          2m
web-server-xxxxx-zzzzz         1/1     Running   0          5s
```

---

## 10.9. Diagnóstico

### Pods em Pending com "Too many pods"

```sh
kubectl describe node | grep pods
```

Se o valor for baixo (ex: `10`), é necessário aumentar o limite:

```sh
sudo sed -i 's/max-pods=10/max-pods=50/' /etc/systemd/system/k3s.service
sudo systemctl daemon-reload
sudo systemctl restart k3s
```

Após o restart, os pods devem sair de `Pending`.

### Application não sincroniza

```sh
argocd app get web-server-argocd-application
argocd app sync web-server-argocd-application
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=50
```

### Root app não encontra as Applications

Verificar se o path no Git está correto: deve apontar para `argocd/applications/`.

### SyncFailed por API version mismatch

```sh
kubectl get application root-app -n argocd -o yaml | grep -A5 "SyncError\|message:"
```

Se a mensagem indicar `traefik.containo.us` não encontrado, o cluster tem Traefik 3+ (API group `traefik.io`). Atualize os manifestos e re-sincronize:

```sh
argocd app sync root-app
```

### IngressRoute não funciona

```sh
kubectl get ingressroute -n argocd
kubectl get secret argocd-tls -n argocd
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=30
```

### "Permission denied" no Project

```sh
argocd proj get homelab
```

Se faltar permissão para IngressRoute/ServersTransport, edite `argocd/projects/homelab-project.yaml`.

### Login falha

```sh
kubectl delete secret argocd-initial-admin-secret -n argocd
kubectl rollout restart deployment argocd-server -n argocd
kubectl wait --for=condition=Ready pods -n argocd -l app.kubernetes.io/name=argocd-server
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

---

## Observação

```text
Este guia foi testado em um notebook com Debian 13, 4 vCPUs, 8 GB RAM e Wi-Fi Realtek. O Argo CD consome aproximadamente 500-800 MiB de RAM. Verifique com kubectl top nodes se há recurso suficiente antes de instalar.

Importante: o limite max-pods do K3s deve ser >= 20 para acomodar os 7 pods do Argo CD junto com os pods do sistema e da aplicação. Antes de instalar, confirme com kubectl describe node | grep pods. Se for igual a 10, edite /etc/systemd/system/k3s.service e altere para max-pods=50 (consulte o Capítulo 3).
```

---

## ✅ Próximo passo

Com o GitOps estabelecido, consulte o diagnóstico completo do cluster:

👉 [11-status-atual.md](11-status-atual.md)
