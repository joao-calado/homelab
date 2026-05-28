#!/bin/bash
# preflight.sh – Verifica se o sistema está apto para receber o homelab
# Execute com: sudo bash preflight.sh (algumas verificações precisam de root)

set -e

echo "=== Homelab Preflight Check ==="
echo

# 1. Verificar distribuição e versão
echo "1. Sistema operacional:"
if grep -q "Debian" /etc/os-release; then
    VERSION=$(grep VERSION_ID /etc/os-release | cut -d= -f2 | tr -d '"')
    echo "   ✅ Debian $VERSION detectado"
else
    echo "   ⚠️ Este guia foi feito para Debian 13. Você pode ter que adaptar comandos."
fi

# 2. Verificar recursos mínimos (4 vCPUs, 8GB RAM)
echo
echo "2. Recursos de hardware:"
CPU_CORES=$(nproc)
RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
RAM_GB=$((RAM_KB / 1024 / 1024))
echo "   CPU cores: $CPU_CORES"
echo "   RAM: ${RAM_GB}GB"
if [ $CPU_CORES -lt 4 ] || [ $RAM_GB -lt 8 ]; then
    echo "   ❌ Recursos abaixo do recomendado (4 vCPUs e 8GB RAM)"
    echo "      O cluster pode funcionar, mas com desempenho reduzido."
else
    echo "   ✅ Recursos suficientes"
fi

# 3. Verificar conectividade com gateway (presume que já está conectado)
echo
echo "3. Teste de ping no gateway padrão (192.168.1.1):"
if ip route | grep default | grep -q .; then
    GATEWAY=$(ip route | grep default | awk '{print $3}' | head -1)
    echo "   Gateway detectado: $GATEWAY"
    if ping -c 2 -W 3 "$GATEWAY" > /dev/null 2>&1; then
        echo "   ✅ Ping bem-sucedido"
    else
        echo "   ❌ Ping falhou. Verifique sua conexão de rede."
    fi
else
    echo "   ❌ Nenhum gateway padrão encontrado. Configure o IP via DHCP ou estático."
fi

# 4. Verificar se o K3s já está instalado (evitar conflitos)
echo
echo "4. Verificando instalação existente do K3s:"
if command -v k3s &> /dev/null; then
    echo "   ⚠️ K3s já está instalado. Execute 'sudo /usr/local/bin/k3s-uninstall.sh' se quiser recomeçar."
else
    echo "   ✅ Nenhuma instalação do K3s detectada."
fi

# 5. Verificar serviços que podem conflitar (NetworkManager, systemd-resolved)
echo
echo "5. Serviços de rede:"
if systemctl is-active --quiet NetworkManager; then
    echo "   ✅ NetworkManager ativo (recomendado)"
else
    echo "   ❌ NetworkManager não está rodando – necessário para este guia."
fi

# 6. Verificar nome da interface Wi-Fi
echo
echo "6. Interface Wi-Fi detectada:"
WIFI_IFACE=$(ip link show | grep -E '^[0-9]+: wl' | cut -d: -f2 | tr -d ' ' | head -1)
if [ -n "$WIFI_IFACE" ]; then
    echo "   ✅ $WIFI_IFACE"
    echo "   Atenção: Lembre-se de substituir 'wlp3s0' nos comandos pelo nome da sua interface: $WIFI_IFACE"
else
    echo "   ⚠️ Nenhuma interface Wi-Fi encontrada. Verifique seus drivers."
fi

# 7. Verificar power saving atual
echo
echo "7. Status do Power Management na interface Wi-Fi:"
if [ -n "$WIFI_IFACE" ]; then
    if iwconfig "$WIFI_IFACE" 2>/dev/null | grep -q "Power Management:off"; then
        echo "   ✅ Power Management já está desativado"
    else
        echo "   ⚠️ Power Management ativo. Você precisará desativar (sudo iwconfig $WIFI_IFACE power off)"
    fi
else
    echo "   Interface não encontrada – pular"
fi

# 8. Sugestão final
echo
echo "=== Resumo ==="
echo "Se todas as verificações acima estiverem verdes, você pode prosseguir com o guia."
echo "Caso contrário, resolva os itens destacados antes de continuar."
echo "Para maiores detalhes, consulte a documentação em docs/01-preparacao.md"