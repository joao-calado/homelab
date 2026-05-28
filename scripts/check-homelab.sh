#!/bin/bash
# check-homelab.sh – Diagnóstico rápido do cluster homelab

set -e

GATEWAY="192.168.1.1"
WIFI_INTERFACE="wlp3s0"
CONNECTION_NAME="JOAO CALADO"

echo "=== Homelab Checker ==="
echo

# 1. Ping no gateway
echo "1. Ping no gateway ($GATEWAY):"
if ping -c 2 -W 3 "$GATEWAY" > /dev/null 2>&1; then
    echo "   ✅ Sucesso"
else
    echo "   ❌ Falhou – verifique o watchdog ou reinicie a conexão"
    echo "      Comando para reciclar manualmente:"
    echo "      sudo nmcli connection down \"$CONNECTION_NAME\" && sudo nmcli connection up \"$CONNECTION_NAME\""
fi

# 2. Serviço K3s
echo
echo "2. Serviço K3s:"
if systemctl is-active --quiet k3s; then
    echo "   ✅ Ativo"
else
    echo "   ❌ Inativo (sudo systemctl restart k3s)"
fi

# 3. Nós do cluster
echo
echo "3. Nós do cluster (kubectl get nodes):"
if kubectl get nodes 2>/dev/null | grep -q Ready; then
    kubectl get nodes
else
    echo "   ❌ Nenhum nó Ready. Verifique logs: journalctl -u k3s --lines=30"
fi

# 4. Pods em estado crítico
echo
echo "4. Pods não saudáveis (excluindo Completed):"
UNHEALTHY=$(kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded 2>/dev/null | tail -n +2 | grep -v "Completed")
if [ -z "$UNHEALTHY" ]; then
    echo "   ✅ Nenhum pod problemático"
else
    echo "   ❌ Pods com problemas:"
    echo "$UNHEALTHY"
fi

# 5. Watchdog (últimos logs)
echo
echo "5. Últimas 3 entradas do watchdog Wi-Fi:"
if journalctl -t wifi-watchdog --no-pager -n 3 2>/dev/null | grep -q .; then
    journalctl -t wifi-watchdog --no-pager -n 3
else
    echo "   Nenhum log encontrado. Verifique se o timer está ativo:"
    echo "   sudo systemctl status wifi-watchdog.timer"
fi

# 6. Erros recentes no K3s
echo
echo "6. Últimos erros do K3s (journalctl -u k3s --priority=err -n 5):"
journalctl -u k3s --priority=err --no-pager -n 5 2>/dev/null || echo "   Nenhum erro encontrado."

# 7. NetworkManager e power saving
echo
echo "7. Power saving Wi-Fi:"
if iwconfig "$WIFI_INTERFACE" 2>/dev/null | grep -q "Power Management:off"; then
    echo "   ✅ Power Management: off"
else
    echo "   ⚠️ Power Management ainda ativo. Execute: sudo iwconfig $WIFI_INTERFACE power off"
fi

echo
echo "=== Fim do diagnóstico ==="