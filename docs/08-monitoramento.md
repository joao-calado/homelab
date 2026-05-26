# 8. Monitoramento do cluster

Este capítulo reúne os comandos `kubectl` mais úteis para observar o estado do cluster, diagnosticar problemas e acompanhar eventos em tempo real.

---

## 8.1. Visão geral dos recursos

1. Comando para listar todos os pods em todos os namespaces com atualização contínua:

```sh
kubectl get pods -A -w
```

2. Descrição:

```text
-A: Todos os namespaces.
-w: Watch – atualiza a tela automaticamente quando há mudanças.
```

1. Comando para listar com mais detalhes (IP, nó, reinicializações):

```sh
kubectl get pods -o wide -w
```

2. Descrição:

```text
-o wide: Exibe colunas adicionais (IP do pod, nó onde está rodando, restart count).
```

1. Comando para ver deployments, serviços e ingress juntos:

```sh
kubectl get deploy,svc,ingress -o wide
```

2. Descrição:

```text
Mostra o estado resumido dos principais recursos da aplicação.
```

---

## 8.2. Métricas de CPU e memória (requer metrics-server)

O K3s já inclui o metrics-server por padrão. Verifique se está rodando:

```sh
kubectl get pods -n kube-system -l k8s-app=metrics-server
```

1. Comando para ver o consumo atual dos pods:

```sh
kubectl top pods -A
```

2. Descrição:

```text
Exibe o uso de CPU e memória por pod no momento. A CPU é mostrada em milicores (m) e a memória em MiB ou GiB.
```

1. Comando para ver o consumo dos nós:

```sh
kubectl top nodes
```

2. Descrição:

```text
Mostra o uso agregado de recursos em cada nó do cluster.
```

---

## 8.3. Logs

1. Comando para acompanhar logs de um pod específico (últimas 20 linhas e follow):

```sh
kubectl logs -f <nome-do-pod> --tail=20
```

2. Descrição:

```text
-f: Segue os logs em tempo real (como tail -f).
--tail=20: Mostra apenas as últimas 20 linhas antes de começar a seguir.
```

1. Comando para ver logs de todos os pods com a label `app=nginx-teste` (útil para o deployment `web-server`):

```sh
kubectl logs -f -l app=nginx-teste --prefix --tail=1
```

2. Descrição:

```text
-l app=nginx-teste: Seleciona pods com essa label.
--prefix: Adiciona o nome do pod antes de cada linha de log.
--tail=1: Mostra apenas a última linha de cada pod (evita poluição).
```

---

## 8.4. Descrição detalhada de recursos

1. Comando para descrever um pod (eventos, condições, montagens de volume, etc.):

```sh
kubectl describe pod <nome-do-pod>
```

2. Descrição:

```text
O describe é a ferramenta mais importante para diagnosticar problemas: mostra a seção Events, que contém erros como "Failed to pull image", "Insufficient memory", "Liveness probe failed", etc.
```

1. Comando para descrever um deployment:

```sh
kubectl describe deployment web-server
```

2. Descrição:

```text
Útil para ver a estratégia de rollout, réplicas desejadas vs disponíveis, e eventos relacionados ao deployment.
```

---

## 8.5. Eventos do cluster

1. Comando para listar todos os eventos ordenados pelo timestamp:

```sh
kubectl get events -A --sort-by='.lastTimestamp'
```

2. Descrição:

```text
-A: Todos os namespaces.
--sort-by: Ordena pelo campo lastTimestamp (mais recentes por último ou primeiro, dependendo da ordem; use .lastTimestamp para ascendente, ou .lastTimestamp com reverse).
```

1. Comando para acompanhar eventos em tempo real:

```sh
kubectl get events -A -w
```

2. Descrição:

```text
Útil durante um rollout ou quando um pod está crashando – os eventos aparecem na tela assim que ocorrem.
```

---

## 8.6. Acompanhar rollout de um deployment

1. Comando:

```sh
kubectl rollout status deployment/web-server
```

2. Descrição:

```text
Mostra o progresso da atualização (ou rollback) do deployment. Aguarda até que todas as réplicas novas estejam prontas antes de retornar sucesso.
```

1. Comando para ver o histórico de revisões do deployment:

```sh
kubectl rollout history deployment/web-server
```

2. Descrição:

```text
Lista as revisões anteriores, permitindo reverter com rollout undo.
```

---

## 8.7. Exemplo prático de diagnóstico (pod pendente)

1. Listar pods:

```sh
kubectl get pods
```

2. Ver um pod em estado `Pending` ou `CrashLoopBackOff`:

```sh
kubectl describe pod <nome-do-pod>
```

3. Examinar a seção **Events** no final da saída. Exemplos comuns:

```text
0/1 nodes are available: 1 Insufficient memory.
Failed to pull image "nginx:alpine": context deadline exceeded.
Readiness probe failed: HTTP probe failed with statuscode 500.
```

4. Se o pod estiver crashando, veja os logs da última execução:

```sh
kubectl logs <nome-do-pod> --previous
```

2. Descrição:

```text
--previous: Mostra os logs da execução anterior (útil quando o pod reiniciou).
```

---

## Observação

```text
Mantenha um terminal dedicado com `kubectl get pods -A -w` enquanto estiver fazendo alterações no cluster. Ele mostra em tempo real a criação, término e erros dos pods.
```

---

## ✅ Próximo passo

Com as ferramentas de monitoramento dominadas, você pode realizar operações de manutenção, como escalar réplicas e reiniciar deployments:

👉 [09-manutencao.md](09-manutencao.md)