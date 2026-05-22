# 🏠 HomeLab – Transforme um notebook antigo em um cluster Kubernetes com K3s

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![K3s version](https://img.shields.io/badge/K3s-v1.32+-orange)](https://k3s.io)

Este repositório documenta **passo a passo** a construção de um laboratório caseiro usando um notebook antigo (Debian 13, 4 vCPUs, ~8GB RAM, Wi-Fi). O objetivo é rodar um cluster Kubernetes de produção local (K3s) com uma aplicação web de exemplo, incluindo:

- Instalação e configuração do K3s com parâmetros personalizados.
- Correção de problemas comuns de rede Wi-Fi (driver instável, DNS interno, power saving).
- Watchdog automático para reciclar a conexão Wi-Fi quando ela trava.
- Deployment de uma aplicação Nginx com anti‑cache no navegador e cabeçalhos de debug.

> 🎯 **Público-alvo:** entusiastas de infraestrutura, estudantes de Kubernetes e qualquer pessoa com um notebook sobrando que queira aprender na prática.

---

## 📋 Pré‑requisitos

- Notebook com **Debian 13 (ou superior)** instalado.
- Acesso à internet via Wi-Fi (ou Ethernet, mas ajuste os comandos).
- Pelo menos **4 vCPUs** e **8 GB de RAM** (recomendado).
- Conexão com o roteador local (IP estático configurável).

---

## 🗂️ Índice da documentação

1. [Preparação inicial](docs/01-preparacao.md) – sudo, curl, lm-sensors, recursos do sistema.
2. [Configuração de rede Wi-Fi](docs/02-configuracao-wifi.md) – IP estático, power save, offloads, conntrack.
3. [Instalação do K3s](docs/03-instalacao-k3s.md) – script de instalação e edição do systemd.
4. [Ajustes finos – DNS e NetworkManager](docs/04-ajustes-finos.md) – resolver o problema de DNS interno.
5. [Watchdog do Wi-Fi](docs/05-watchdog-wifi.md) – script + systemd timer para conexão resiliente.
6. [Primeira aplicação](docs/06-primeira-aplicacao.md) – Deployment, Service e Ingress básicos.
7. [Anti‑cache no navegador](docs/07-anti-cache.md) – evitando cache com cabeçalhos HTTP.
8. [Monitoramento](docs/08-monitoramento.md) – comandos `kubectl` essenciais.
9. [Manutenção do cluster](docs/09-manutencao.md) – escala, restart, limpeza.
10. [Estado atual e diagnóstico](docs/10-status-atual.md) – fluxo de requisição e troubleshooting.

---

## 🚀 Começo rápido (se você já tiver o cluster rodando)

```bash
# Clone este repositório
git clone https://github.com/seu-usuario/homelab.git
cd homelab

# Aplique a aplicação de exemplo
kubectl apply -f manifests/app.yaml

# Acesse no navegador
# http://nginx.192.168.1.200.nip.io
```

> **Nota:** Substitua `192.168.1.200` pelo IP do seu notebook.

---

## 🧠 Solução de problemas em 4 passos

1. Verifique a conectividade Wi-Fi:
   ```bash
   ping 192.168.1.1
   ```
2. Veja os logs do watchdog:
   ```bash
   journalctl -t wifi-watchdog -f
   ```
3. Analise os logs do K3s:
   ```bash
   journalctl -u k3s -f
   ```
4. Liste o estado dos pods:
   ```bash
   kubectl get pods -A
   ```

---

## 🤝 Contribuição

Sinta‑se à vontade para abrir issues e pull requests com melhorias, correções ou novas ideias.

## 📜 Licença

MIT – use e adapte livremente, mas mantenha os créditos. Veja o arquivo [LICENSE](LICENSE).

## 🙏 Agradecimentos

Agradeço ao excelente trabalho da equipe do K3s (Rancher) e à comunidade Debian.
