# SPDX-FileCopyrightText: 2026 Andrey Tokarev
# SPDX-License-Identifier: LicenseRef-Flint-VPN-Noncommercial-1.0
# The dns tab of the panel: this body runs inside the case of panel.cgi.
  DOH="$(flint-dns doh)"; DNSCRYPT="$(flint-dns dnscrypt)"; UDP="$(flint-dns udp)"; DNSMODE="$(flint-dns mode)"
  # dns_card <mode> <title> <hint>: a card per mode; the one in use is marked.
  dns_card() {
    used=""; [ "$1" = "$DNSMODE" ] && used=" <small class=ok>· $(T "используется" "in use")</small>"
    echo "<div class=card><h2>$2$used</h2><small>$3</small>"
  }
  # dns_select <action> doh|dnscrypt|udp <current> <button>: a preset list that sends <action>=<name>.
  dns_select() {
    echo "<form method=get class=row>$(hidden)<select name=$1>"
    flint-dns presets "$2" | esc | while IFS="$TAB" read -r n title; do
      sel=""; [ "$n" = "$3" ] && sel=" selected"
      case "$2:$n" in doh:cloudflare|dnscrypt:adguard-unfiltered) title="$title — $(T "по умолчанию" "default")" ;; esac
      echo "<option value=$n$sel>$title</option>"
    done
    echo "</select><button>$4</button></form>"
  }
  echo "<div class=card><h2>DNS</h2><small>$(T "Через этот DNS роутер узнаёт адреса сайтов для всех устройств сети. Если выбранный сервер не ответит, останется прежний." \
    "The router looks up site addresses for every device on the network through this DNS. If the chosen server does not answer, the previous one stays.")</small>"
  echo "<p>$(T "Сейчас" "Now"): <b class=ok>$(flint-dns title | esc)</b></p></div>"
  dns_card doh "$(T "DoH — зашифрованный" "DoH — encrypted")" "$(T "Запросы идут по HTTPS: провайдер не видит, какие сайты открываются, и не может подменить ответ." \
    "Queries go over HTTPS: the provider does not see which sites are opened and cannot spoof the answers.")"
  dns_select dns doh "$DOH" "$(T "Использовать DoH" "Use DoH")"
  url=""; case "$DOH" in https://*) url="$(echo "$DOH" | esc)" ;; esac
  echo "<form method=get class=row>$(hidden)<input type=text name=dnsurl value='$url' placeholder='https://dns.example.com/dns-query' required>"
  echo "<button>$(T "Свой DoH-сервер" "Own DoH server")</button></form></div>"
  dns_card dnscrypt "$(T "DNSCrypt — зашифрованный" "DNSCrypt — encrypted")" "$(T "Отдельный протокол шифрования DNS. Пригодится, если DoH в сети блокируют. Свой сервер задаётся stamp'ом sdns:// из списка dnscrypt.info." \
    "A separate DNS encryption protocol. Useful when DoH is blocked on the network. An own server is set with an sdns:// stamp from the dnscrypt.info list.")"
  dns_select dnscrypt dnscrypt "$DNSCRYPT" "$(T "Использовать DNSCrypt" "Use DNSCrypt")"
  stamps=""; case "$DNSCRYPT" in sdns://*) stamps="$(echo "$DNSCRYPT" | esc)" ;; esac
  echo "<form method=get class=row>$(hidden)<input type=text name=dnsstamp value='$stamps' placeholder='sdns://...' required>"
  echo "<button>$(T "Свой DNSCrypt-сервер" "Own DNSCrypt server")</button></form></div>"
  dns_card udp "$(T "Обычный DNS (UDP)" "Plain DNS (UDP)")" "$(T "Запросы идут открыто: провайдер их видит и может подменить. Пригодится, если шифрованный DNS в вашей сети не работает или нужен DNS основного роутера." \
    "Queries go in the clear: the provider sees them and can spoof them. Useful when encrypted DNS does not work on your network or you need the main router's DNS.")"
  dns_select dnsudp udp "$UDP" "$(T "Использовать UDP" "Use UDP")"
  ips=""; echo "$UDP" | grep -qE '^[0-9. ]+$' && ips="$UDP"
  echo "<form method=get class=row>$(hidden)<input type=text name=dnsip value='$ips' placeholder='1.1.1.1 8.8.8.8' required>"
  echo "<button>$(T "Свои DNS-серверы" "Own DNS servers")</button></form></div>"
  # Tunnel: the router's own DNS goes through the VPN, so blocking the resolver by name does not matter.
  dns_card tunnel "$(T "Через туннель" "Through the tunnel")" "$(T "Запросы уходят через VPN на выбранный сервер, поэтому провайдер не видит ни имена, ни сам резолвер. Помогает, когда DoH и DNSCrypt перестали отвечать из-за блокировки по имени сервера. Не работает при выключенном VPN или без серверов." \
    "Queries go through the VPN to the server, so the provider sees neither the names nor the resolver. Helps when DoH and DNSCrypt stopped answering because the resolver name is blocked. Needs a working VPN: it does not work with the VPN off.")"
  if [ "$DNSMODE" = tunnel ]; then
    echo "$ON — $(T "адреса сайтов роутер узнаёт через VPN, переключение обратно вернёт прежний режим." "the router looks up site addresses through the VPN; switching back restores the previous mode.")"
    btn dnsmode doh "" "$(T "Вернуться к DoH" "Back to DoH")"
  else
    btn dnsmode tunnel " class=on" "$(T "Использовать туннель" "Use the tunnel")"
  fi
  echo "</div>"
  DEL="$(T "Удалить" "Delete")"
  echo "<div class=card><h2>$(T "Локальные имена" "Local names")</h2><small>$(T "Устройство в сети открывается по имени вместо IP: nas01, nas01.lan и nas01.local. Имя с точкой, например nas.home, работает как есть. Повторное добавление имени меняет его адрес. Закрепите за устройством постоянный IP на роутере, который его выдаёт, иначе имя может перестать работать после перезагрузки." \
    "A device on the network opens by name instead of IP: nas01, nas01.lan and nas01.local. A name with a dot, such as nas.home, works as is. Adding a name again changes its address. Give the device a fixed IP on the router that hands it out, or the name may stop working after a reboot.")</small>"
  HOSTS="$(flint-dns hosts | esc)"
  [ -n "$HOSTS" ] || echo "<p><small>$(T "пока нет" "none yet")</small></p>"
  echo "$HOSTS" | while IFS="$TAB" read -r n ip; do
    [ -n "$n" ] || continue
    echo "<form method=get class=item>$(hidden)<input type=hidden name=hostdel value='$n'><span>$n<br><small>$ip</small></span><button title='$DEL'>✕</button></form>"
  done
  echo "<form method=get class=row>$(hidden)<input type=text name=hostadd placeholder='nas01' required>"
  echo "<input type=text name=hostip placeholder='192.168.0.145' list=lan-devices required><button>$(T "Добавить имя" "Add a name")</button></form>"
  echo "<datalist id=lan-devices>"
  flint-adblock devices | esc | while IFS="$TAB" read -r m ip name; do echo "<option value='$ip'>${name:-$m}</option>"; done
  echo "</datalist></div>"
