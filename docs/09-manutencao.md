# 9. Manutenção do cluster

Este capítulo cobre as operações mais comuns do dia a dia: escalar aplicações, reiniciar deployments sem downtime, limpar recursos ociosos, reiniciar o K3s e remover recursos.

---

## 9.1. Escalar réplicas

1. Comando para aumentar (ou reduzir) o número de réplicas do deployment `web-server`:

```sh
kubectl scale deployment web-server --replicas=3
```

2. Descrição:

```text
--replicas=3: Define que o deployment deve ter exatamente 3 pods.
O Kubernetes criará ou removerá pods automaticamente para atingir o número desejado.
```

**Verificar**:

```sh
kubectl get pods -l app=nginx-teste
```

---

## 9.2. Rolling restart (forçar recriação dos pods)

Útil quando você precisa aplicar mudanças que não estão no manifesto (ex.: secrets montadas via volume, ou simplesmente resetar os pods).

1. Comando:

```sh
kubectl rollout restart deployment web-server
```

2. Descrição:

```text
Realiza um rolling restart: termina os pods gradualmente e cria novos, sem downtime (desde que haja mais de uma réplica).
```

**Acompanhar o progresso**:

```sh
kubectl rollout status deployment/web-server
```

---

## 9.3. Limpar pods no estado `Completed`

No namespace `kube-system`, o Traefik deixa um pod `helm-install-traefik` em estado `Completed` após a instalação. Removê-lo é seguro e evita poluição visual.

1. Comando para remover todos os pods `Completed` no namespace `kube-system`:

```sh
kubectl delete pod -n kube-system --field-selector=status.phase=Succeeded
```

2. Descrição:

```text
--field-selector=status.phase=Succeeded: Seleciona apenas pods que terminaram com sucesso (Completed).
```

**Atenção:** Não remova pods `Running` ou `Pending`.

---

## 9.4. Reiniciar o serviço K3s (no nó master)

Se você editar o arquivo de serviço do K3s ou precisar reiniciar o cluster por qualquer motivo:

1. Recarregar o systemd (se o serviço foi editado):

```sh
sudo systemctl daemon-reload
```

2. Reiniciar o K3s:

```sh
sudo systemctl restart k3s
```

3. Descrição:

```text
Restartar o K3s mata todos os pods e os recria. O cluster fica indisponível por alguns segundos. Use com cautela em produção.
```

---

## 9.5. Ver e editar o serviço K3s

1. Ver o conteúdo completo do unit do K3s:

```sh
cat /etc/systemd/system/k3s.service
```

2. Editar diretamente o arquivo (substitua `nano` pelo editor de sua preferência):

```sh
sudo nano /etc/systemd/system/k3s.service
```

Após editar, sempre execute `sudo systemctl daemon-reload` e reinicie o serviço.

---

## 9.6. Remover a aplicação

1. Remover todos os recursos definidos no manifesto `app.yaml` (Deployment, Service, Ingress):

```sh
kubectl delete -f manifests/app.yaml
```

2. Para remover apenas o deployment (os serviços e ingress permanecem, mas sem pods para responder):

```sh
kubectl delete deployment web-server
```

3. Descrição:

```text
Ao deletar o deployment, os pods são terminados, mas o Service e o Ingress ficam (podem ser úteis para outro deployment futuro).
```

---

## Observação

```text
Sempre teste comandos de exclusão e reinicialização em um ambiente de desenvolvimento antes de aplicá-los em produção (ainda que caseira). O rolling restart é seguro, mas reiniciar o K3s derruba o cluster momentaneamente.
```

---

## ✅ Próximo passo

Com as práticas de manutenção dominadas, vamos implementar GitOps com Argo CD:

👉 [10-gitops-argo-cd.md](10-gitops-argo-cd.md)
