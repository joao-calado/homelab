# 2. Configuração de rede Wi-Fi para estabilidade

> **Nota importante:** neste guia, a interface Wi-Fi é chamada de `wlp3s0` (exemplo do meu notebook). **Você deve substituir esse nome pelo nome da sua própria interface**, que pode ser descoberto com o comando `ip link show` ou `iwconfig`. Nomes comuns incluem `wlan0`, `wlx...`, `enp...`, etc.

A configuração correta do Wi-Fi é essencial para evitar quedas de conexão. Este capítulo cobre IP estático, desativação de power saving e ajustes específicos para o chipset Realtek (se aplicável).

---

## 2.1. Configurar IP estático via `nmcli`

Substitua `"JOAO CALADO"` pelo nome exato da sua conexão Wi-Fi (verifique com `nmcli connection show`). Substitua `wlp3s0` pelo nome da sua interface Wi-Fi.

1. Comando:

```sh
sudo nmcli connection modify "JOAO CALADO" ipv4.method manual ipv4.addresses 192.168.1.200/24 ipv4.gateway 192.168.1.1 ipv4.dns "192.168.1.1"
sudo nmcli connection down "JOAO CALADO"
sudo nmcli connection up "JOAO CALADO"
```

2. Descrição:

```text
nmcli connection modify: Altera a configuração da conexão. Define método manual (IP fixo), endereço 192.168.1.200/24, gateway 192.168.1.1 e servidor DNS 192.168.1.1.
nmcli connection down/up: Reinicia a conexão para aplicar as mudanças.
Verifique com: ip a show wlp3s0 (substitua wlp3s0) e resolvectl status wlp3s0.
```

---

## 2.2. Desabilitar power saving do Wi-Fi (definitivo)

O power saving pode desligar partes da placa Wi-Fi quando ociosa, causando falhas de conectividade em servidores. Use o comando `iwconfig` para desativá-lo imediatamente.

1. Comando (substitua `wlp3s0` pela sua interface):

```sh
sudo iwconfig wlp3s0 power off
```

2. Descrição:

```text
Desativa o gerenciamento de energia (power management) da sua interface Wi-Fi. O efeito é imediato. Para verificar se a configuração foi aplicada, execute (substitua wlp3s0):
```

```sh
iwconfig wlp3s0
```

Exemplo de saída esperada (observe `Power Management:off` – os campos como ESSID e Access Point foram ofuscados por segurança):

```text
wlp3s0    IEEE 802.11  ESSID:"MINHA_REDE"
          Mode:Managed  Frequency:2.437 GHz  Access Point: XX:XX:XX:XX:XX:XX
          Bit Rate=72.2 Mb/s   Tx-Power=20 dBm
          Power Management:off
          ...
```

**Importante:** Essa configuração é volátil (será perdida após reinicialização). Para torná-la persistente, crie um script em `/etc/network/if-up.d/` ou uma regra udev, mas o foco aqui é desativar manualmente para testes imediatos.

---

## 2.3. Ajustes para driver Realtek (rtl8723be)

Se seu notebook usa o chipset Realtek RTL8723BE (comum em modelos antigos), adicione parâmetros para evitar travamentos. Caso seu chipset seja outro, este passo é opcional.

1. Comando:

```sh
echo "options rtl8723be fwlps=0 ips=0 swenc=1" | sudo tee /etc/modprobe.d/rtl8723be.conf
sudo rmmod rtl8723be && sudo modprobe rtl8723be
```

2. Descrição:

```text
fwlps=0: Desativa o power saving falso do firmware.
ips=0: Desativa o power saving automático.
swenc=1: Força criptografia por software (evita hangs).
O módulo é removido e recarregado para aplicar os parâmetros imediatamente.
```

---

## Observação

```text
Todas essas configurações foram necessárias porque optei por não utilizar cabo ethernet (o notebook não possui porta ou não quero usá-la) e também não tenho acesso à senha do roteador – o equipamento é fornecido pelo provedor de nuvem (ISP) e as configurações administrativas são bloqueadas. Portanto, todo o controle se restringe ao lado do cliente (meu notebook), exigindo ajustes finos no sistema operacional e no driver para garantir estabilidade.
```

---

## ✅ Próximo passo

A rede Wi-Fi agora está estabilizada. Prossiga para a instalação do K3s (lembre-se de que o flannel será desabilitado em etapas posteriores):

👉 [03-instalacao-k3s.md](03-instalacao-k3s.md)
