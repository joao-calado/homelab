#!/bin/bash
GATEWAY="192.168.1.1"
CONNECTION="JOAO CALADO"

if ! ping -c 2 -W 5 "$GATEWAY" > /dev/null 2>&1; then
    echo "$(date): Ping falhou. Reciclando conexão Wi-Fi..." | systemd-cat -t wifi-watchdog
    nmcli connection down "$CONNECTION"
    sleep 3
    nmcli connection up "$CONNECTION"
fi