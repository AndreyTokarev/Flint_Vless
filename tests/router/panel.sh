# Panel actions through panel.cgi: every tab renders, each request runs exactly the action it names.
. "$(dirname "$0")/lib.sh"
echo "== panel: tabs and actions"
save_state
pin="$(sed -n 's/^UI_PIN=//p' /etc/xray/flint.env | tr -d '"')"
# panel <query>: the Russian page for the query (without pass and lang).
panel() { wget -qO- "http://127.0.0.1:81/cgi-bin/panel.cgi?pass=$pin&lang=ru&$1"; }
page_ok() { panel "$1" | grep -c '</html>'; }
for t in status servers own subs routing adblock dns telegram settings; do check "tab $t renders" page_ok "tab=$t"; done
check "no hidden action fields" fails sh -c "wget -qO- 'http://127.0.0.1:81/cgi-bin/panel.cgi?pass=$pin&tab=servers' | grep -c 'name=a '"
check "wrong PIN shows the login form" sh -c "wget -qO- 'http://127.0.0.1:81/cgi-bin/panel.cgi?pass=bad' | grep -c 'type=password'"
check "status shows the provider IP" panel_has status 'IP провайдера'
check "settings shows the PIN form" panel_has settings 'name=pinold'
panel "tab=settings&pin=1&pinold=bad&pinnew=zzPinTest9&pinok=zzPinTest9" >/tmp/flint-test-pin
check "PIN change rejects a wrong current PIN" grep -q 'Неверный текущий PIN' /tmp/flint-test-pin
check "PIN unchanged after a rejected change" [ "$(sed -n 's/^UI_PIN=//p' /etc/xray/flint.env | tr -d '"')" = "$pin" ]
panel "tab=settings&pin=1&pinold=$pin&pinnew=zzPinTest9&pinok=zzPinOther" >/tmp/flint-test-pin
check "PIN change rejects a mismatched confirmation" grep -q 'не совпадают' /tmp/flint-test-pin
panel "tab=settings&pin=1&pinold=$pin&pinnew=zz%23Pin9&pinok=zz%23Pin9" >/tmp/flint-test-pin
check "PIN change rejects other characters" grep -q 'только буквы и цифры' /tmp/flint-test-pin
panel "tab=settings&pin=1&pinold=$pin&pinnew=zzPinTest9&pinok=zzPinTest9" >/tmp/flint-test-pin
check "PIN change reports success" grep -q 'PIN изменён' /tmp/flint-test-pin
check "new PIN is in flint.env" [ "$(sed -n 's/^UI_PIN=//p' /etc/xray/flint.env | tr -d '"')" = zzPinTest9 ]
check "new PIN opens the panel" sh -c "wget -qO- 'http://127.0.0.1:81/cgi-bin/panel.cgi?pass=zzPinTest9&tab=settings' | grep -c 'name=pinold'"
wget -qO- "http://127.0.0.1:81/cgi-bin/panel.cgi?pass=zzPinTest9&lang=ru&tab=settings&pin=1&pinold=zzPinTest9&pinnew=$pin&pinok=$pin" >/dev/null
check "PIN restored after the test" [ "$(sed -n 's/^UI_PIN=//p' /etc/xray/flint.env | tr -d '"')" = "$pin" ]
rm -f /tmp/flint-test-pin

panel "tab=routing&add=zz-panel-test.example&to=proxy" >/dev/null
check "site add" sh -c "flint-node site list | grep -q zz-panel-test.example"
panel "tab=routing&del=zz-panel-test.example" >/dev/null
check "site del" fails sh -c "flint-node site list | grep -q zz-panel-test.example"
panel "tab=routing&add=zz-bad.example&to=nowhere" >/dev/null
check "site add with a bad list is ignored" fails sh -c "flint-node site list | grep -q zz-bad.example"

mode="$(flint-node routing)"; other=global; [ "$mode" = global ] && other=ru
panel "tab=routing&routing=$other" >/dev/null
check "routing switch" [ "$(flint-node routing)" = "$other" ]
panel "tab=routing&routing=$mode" >/dev/null
check "routing switch back" [ "$(flint-node routing)" = "$mode" ]
# A documentation-range MAC (00:00:5e:00:53:xx): no real device has it.
tm=00:00:5e:00:53:01
direct_listed() { flint-node direct | cut -f1 | grep -qx "$tm"; }
xray_skips() { iptables -t nat -S XRAY | grep -qi -- "--mac-source $tm -j RETURN"; }
quic_allowed() { iptables -S FLINT_QUIC | grep -qi -- "--mac-source $tm -j RETURN"; }
check "routing tab shows the devices without VPN form" panel_has routing 'name=directadd'
panel "tab=routing&directadd=00-00-5E-00-53-01&directname=zz-direct-test" >/dev/null
check "device without VPN added by MAC" direct_listed
check "device without VPN skips xray" xray_skips
check "device without VPN keeps QUIC" quic_allowed
check "QUIC still blocked for the rest" sh -c "iptables -S FLINT_QUIC | tail -n1 | grep -q -- '-j DROP'"
check "routing tab lists the device without VPN" panel_has routing 'zz-direct-test'
panel "tab=routing&directadd=$tm" >/tmp/flint-test-page
check "the same device twice is rejected" [ "$(grep -c 'уже без VPN' /tmp/flint-test-page):$(flint-node direct | grep -c "^$tm")" = 1:1 ]
panel "tab=routing&directadd=not-a-mac" >/tmp/flint-test-page
check "a bad MAC is rejected" grep -q 'Это не MAC-адрес' /tmp/flint-test-page
panel "tab=routing&directdel=$tm" >/dev/null
check "device without VPN deleted" fails direct_listed
check "the deleted device goes via xray again" fails xray_skips
check "the deleted device has QUIC blocked again" fails quic_allowed
rm -f /tmp/flint-test-page

iv="$(flint-sub-update interval)"
panel "tab=subs&subint=6h" >/dev/null
check "subscription interval" [ "$(flint-sub-update interval)" = 6h ]
panel "tab=subs&subint=$iv" >/dev/null

panel "tab=adblock&aballow=zz-allow-test.example" >/dev/null
check "site without blocking added" sh -c "flint-adblock rule | grep -qxF '@@||zz-allow-test.example^'"
check "site without blocking listed" sh -c "wget -qO- 'http://127.0.0.1:81/cgi-bin/panel.cgi?pass=$pin&tab=adblock' | grep -c '<span>zz-allow-test.example</span>'"
panel "tab=adblock&abrdel=%40%40%7C%7Czz-allow-test.example%5E" >/dev/null
check "site without blocking removed" fails sh -c "flint-adblock rule | grep -qF zz-allow-test"

# DNS: a bad address and an unreachable server change nothing; the original setup comes back at the end.
dns_mode="$(flint-dns mode)"; doh="$(flint-dns doh)"; dnscrypt="$(flint-dns dnscrypt)"; udp="$(flint-dns udp)"
dns_title="$(flint-dns title)"
# dns_answers: an address in the answer (busybox nslookup exits 0 on an empty one too).
dns_answers() { nslookup example.com 127.0.0.1 | awk '/^Name:/ { n = 1 } n && /^Address/ { f = 1 } END { exit !f }'; }
check "DNS tab shows the DNS forms" panel_has dns 'name=dnsip'
check "settings no longer hold the DNS forms" fails panel_has settings 'name=dnsip'
panel "tab=dns&dns=google" >/dev/null
check "DoH switch to a preset" [ "$(flint-dns doh)" = google ]
check "DNS answers after the switch" dns_answers
panel "tab=dns&dnsurl=ftp%3A%2F%2Fbad.example" >/tmp/flint-test-page
check "DoH rejects a bad address" grep -q 'Это не адрес DoH-сервера' /tmp/flint-test-page
panel "tab=dns&dnsurl=https%3A%2F%2F127.0.0.1%3A9%2Fdns-query" >/tmp/flint-test-page
check "an unreachable DoH server is rolled back" grep -q 'DNS остался прежним' /tmp/flint-test-page
check "DoH unchanged after the rollback" [ "$(flint-dns doh)" = google ]
check "DNS answers after the rollback" dns_answers
panel "tab=dns&dnsurl=https%3A%2F%2Fdns.google%2Fdns-query" >/dev/null
check "DoH switch to an own address" [ "$(flint-dns doh)" = https://dns.google/dns-query ]
check "status shows the DNS server" panel_has status 'https://dns.google/dns-query'
panel "tab=dns&dnscrypt=quad9-unfiltered" >/dev/null
check "DNSCrypt switch to a preset" [ "$(flint-dns mode):$(flint-dns dnscrypt)" = dnscrypt:quad9-unfiltered ]
check "DNSCrypt config has both servers" [ "$(grep -c '^stamp = .sdns://AQ' /etc/dnscrypt-proxy2/flint-doh.toml)" = 2 ]
check "DNS answers over DNSCrypt" dns_answers
panel "tab=dns&dnsstamp=https%3A%2F%2Fnot-a-stamp" >/tmp/flint-test-page
check "DNSCrypt rejects a bad stamp" grep -q 'stamp сервера' /tmp/flint-test-page
panel "tab=dns&dnsudp=yandex" >/dev/null
check "UDP switch to a preset" [ "$(flint-dns mode):$(flint-dns udp)" = udp:yandex ]
check "dnsmasq asks the UDP servers" [ "$(uci -q get dhcp.@dnsmasq[0].server)" = "77.88.8.8 77.88.8.1" ]
check "DoH resolver stopped in UDP mode" fails sh -c "ps w | grep -v grep | grep -q flint-doh.toml"
check "DNS answers over UDP" dns_answers
panel "tab=dns&dnsip=1.1.1" >/tmp/flint-test-page
check "UDP rejects a bad address" grep -q 'IP-адреса DNS-серверов' /tmp/flint-test-page
panel "tab=dns&dnsip=192.0.2.1" >/tmp/flint-test-page
check "an unreachable UDP server is rolled back" grep -q 'DNS остался прежним' /tmp/flint-test-page
check "UDP unchanged after the rollback" [ "$(flint-dns udp)" = yandex ]
check "DNS answers after the UDP rollback" dns_answers
panel "tab=dns&dnsudp=provider" >/dev/null
check "UDP via the main router's DNS" [ "$(flint-dns udp):$(uci -q get dhcp.@dnsmasq[0].noresolv)" = provider:0 ]
check "DNS answers via the main router" dns_answers
flint-dns mode doh >/dev/null
check "mode switch back to DoH keeps its server" [ "$(flint-dns mode):$(flint-dns doh)" = doh:https://dns.google/dns-query ]
check "DNS answers after the mode switch" dns_answers
flint-dns udp "$udp" >/dev/null 2>&1; flint-dns dnscrypt "$dnscrypt" >/dev/null 2>&1
flint-dns doh "$doh" >/dev/null 2>&1; flint-dns mode "$dns_mode" >/dev/null 2>&1
check "DNS restored after the test" [ "$(flint-dns title)" = "$dns_title" ]
host_ip() { flint-dns hosts | awk -F '\t' -v n="$1" '$1 == n { print $2 }'; }
# resolves <name> <ip>: dnsmasq answers the name with this address.
resolves() { nslookup "$1" 127.0.0.1 2>/dev/null | awk -v ip="$2" '/^Name:/ { n = 1 } n && /^Address/ && $NF == ip { f = 1 } END { exit !f }'; }
check "DNS tab shows the local names form" panel_has dns 'name=hostadd'
panel "tab=dns&hostadd=ZZ-Flint-Test&hostip=192.0.2.55" >/dev/null
check "local name added in lower case" [ "$(host_ip zz-flint-test)" = 192.0.2.55 ]
check "local name resolves" resolves zz-flint-test 192.0.2.55
check "local name resolves with .lan" resolves zz-flint-test.lan 192.0.2.55
check "local name resolves with .local" resolves zz-flint-test.local 192.0.2.55
check "DNS tab lists the local name" panel_has dns 'zz-flint-test'
panel "tab=dns&hostadd=zz-flint-test&hostip=192.0.2.56" >/dev/null
check "adding a name again changes its address" [ "$(host_ip zz-flint-test | grep -c .):$(host_ip zz-flint-test)" = 1:192.0.2.56 ]
check "the new address resolves" resolves zz-flint-test 192.0.2.56
panel "tab=dns&hostadd=zz.flint.test&hostip=192.0.2.57" >/dev/null
check "a dotted name resolves as is" resolves zz.flint.test 192.0.2.57
panel "tab=dns&hostadd=bad_name&hostip=192.0.2.58" >/tmp/flint-test-page
check "local names reject a bad name" [ "$(grep -c 'латинские буквы' /tmp/flint-test-page):$(host_ip bad_name)" = 1: ]
panel "tab=dns&hostadd=zz-flint-bad&hostip=192.0.2.300" >/tmp/flint-test-page
check "local names reject a bad IP" [ "$(grep -c 'IPv4-адрес' /tmp/flint-test-page):$(host_ip zz-flint-bad)" = 1: ]
panel "tab=dns&hostdel=zz-flint-test" >/dev/null
panel "tab=dns&hostdel=zz.flint.test" >/dev/null
check "local names deleted" [ -z "$(host_ip zz-flint-test)$(host_ip zz.flint.test)" ]
check "a deleted name no longer resolves" fails resolves zz-flint-test 192.0.2.56
rm -f /tmp/flint-test-page

# Telegram proxy: switches through the panel; restore_state brings back its settings and stops or restarts it.
tg_listens() { for i in 1 2 3 4 5 6 7 8 9 10; do netstat -ltn | grep -q ":$1 " && return 0; sleep 1; done; return 1; }
# A settings change restarts the proxy: read the command line of the new process once it listens again.
tg_cmd() { sleep 1; tg_listens "$(flint-tg port)"; tr '\0' ' ' < "/proc/$(pidof tg-ws-proxy | cut -d ' ' -f1)/cmdline"; }
tg_cmd_has() { tg_cmd | grep -qF -- "$1"; }
tg_secret_hidden() { ! tg_cmd | grep -qF "$(flint-tg secret)"; }
tg_rule_port() { [ "$(uci -q get firewall.flint_tg_remote.dest_port)" = "$1" ]; }
# The tab shows the switch that matches the proxy's current state: the deploy leaves it on.
if [ "$(flint-tg state)" = on ]; then
	check "Telegram tab shows the off switch" panel_has telegram "name=tg value='off'"
else
	check "Telegram tab shows the on switch" panel_has telegram "name=tg value='on'"
fi
panel "tab=telegram&tg=on" >/tmp/flint-test-page
check "Telegram proxy turned on" grep -q 'Прокси для Telegram включён' /tmp/flint-test-page
check "Telegram proxy listens on its port" tg_listens "$(flint-tg port)"
check "Telegram tab shows the link" panel_has telegram 'tg://proxy?server='
check "the secret stays out of the process list" tg_secret_hidden
check "status shows the Telegram proxy" panel_has status 'Прокси для Telegram'
panel "tab=telegram&tgroute=vpn" >/dev/null
if [ "$(flint-node vpn)" != off ] && [ -s /etc/xray/config.json ]; then
	check "route via VPN uses Xray" tg_cmd_has '--outbound-proxy http://127.0.0.1:1087'
else
	check "route via VPN goes direct while the VPN is off" fails tg_cmd_has '--outbound-proxy'
fi
panel "tab=telegram&tgroute=direct" >/dev/null
check "route direct bypasses Xray" fails tg_cmd_has '--outbound-proxy'
panel "tab=telegram&tgcf=off" >/dev/null
check "Cloudflare fallback off" fails tg_cmd_has '--default-domains'
panel "tab=telegram&tgcf=on" >/dev/null
check "Cloudflare fallback on" tg_cmd_has '--default-domains'
panel "tab=telegram&tgport=81" >/tmp/flint-test-page
check "a port below 1024 is rejected" grep -q 'от 1024 до 65535' /tmp/flint-test-page
# A busy port is any listening port, but flint-tg port checks the allowed range first: a port below
# 1024 is refused as out of range, not as busy. The router's only candidate is 443 (Xray listens on
# it), so accept either refusal and check that the setting did not change.
busy="$(netstat -ltn | awk -v own="$(flint-tg port)" 'NR > 2 { sub(/.*:/, "", $4); if ($4 != own) print $4 }' | head -n1)"
if [ -n "$busy" ]; then
	panel "tab=telegram&tgport=$busy" >/tmp/flint-test-page
	check "a busy port is rejected" grep -qE 'уже занят|от 1024 до 65535' /tmp/flint-test-page
	check "a busy port does not change the setting" [ "$(flint-tg port)" != "$busy" ]
else
	echo "  skip  a busy port is rejected (no listening port found)"
fi
panel "tab=telegram&tgport=1444" >/dev/null
check "port change: listens on the new port" tg_listens 1444
check "port change: the link has the new port" sh -c "flint-tg link | grep -q 'port=1444&'"
panel "tab=telegram&tgremote=on" >/dev/null
check "access from the internet opens the port" tg_rule_port 1444
panel "tab=telegram&tgremote=off" >/dev/null
check "access from the internet closed" fails uci -q get firewall.flint_tg_remote
panel "tab=telegram&tgmask=https%3A%2F%2Fwww.Google.com%2F" >/dev/null
check "masking takes the domain from a link" [ "$(flint-tg mask)" = www.google.com ]
check "masking: FakeTLS in the proxy" tg_cmd_has '--listen-faketls-domain www.google.com'
check "masking: an ee secret in the link" sh -c "flint-tg link | grep -q 'secret=ee[0-9a-f]\{32\}7777772e676f6f676c652e636f6d$'"
panel "tab=telegram&tgmask=off" >/dev/null
check "masking off: a dd secret again" sh -c "flint-tg link | grep -q 'secret=dd[0-9a-f]\{32\}$'"
s="$(flint-tg secret)"
panel "tab=telegram&tgsecret=1" >/dev/null
check "new secret" [ "$(flint-tg secret)" != "$s" ]
panel "tab=telegram&tgsecretset=dd0123456789ABCDEF0123456789abcdef" >/dev/null
check "own secret from a dd link" [ "$(flint-tg secret)" = 0123456789abcdef0123456789abcdef ]
panel "tab=telegram&tgsecretset=xyz" >/tmp/flint-test-page
check "a bad secret is rejected" grep -q 'можно с dd или ee' /tmp/flint-test-page
check "a bad secret keeps the old one" [ "$(flint-tg secret)" = 0123456789abcdef0123456789abcdef ]
panel "tab=telegram&tgdc=2%3A149.154.167.220%2C+4%3A149.154.167.220" >/dev/null
check "data center addresses in the proxy" tg_cmd_has '--dc-ip 2:149.154.167.220 --dc-ip 4:149.154.167.220'
panel "tab=telegram&tgdc=2-1.2.3.4" >/dev/null
check "bad data center address rejected" [ "$(flint-tg dc)" = 2:149.154.167.220,4:149.154.167.220 ]
panel "tab=telegram&tgdc=default" >/dev/null
check "data center addresses: defaults" fails tg_cmd_has '--dc-ip'
panel "tab=telegram&tgcfd=Proxy.Example.com" >/dev/null
check "own Cloudflare domain in the proxy" tg_cmd_has '--cf-domain proxy.example.com'
panel "tab=telegram&tgworker=a.user.workers.dev" >/dev/null
check "Cloudflare Worker in the proxy" tg_cmd_has '--cf-worker-domain a.user.workers.dev'
panel "tab=telegram&tgcftls=off" >/dev/null
check "TLS to Cloudflare off" tg_cmd_has '--cf-disable-tls'
panel "tab=telegram&tgpool=8" >/dev/null
check "pool size in the proxy" tg_cmd_has '--pool-size 8'
panel "tab=telegram&tgpool=99" >/dev/null
check "pool out of range rejected" [ "$(flint-tg pool)" = 8 ]
panel "tab=telegram&tglog=verbose" >/dev/null
check "verbose log in the proxy" tg_cmd_has '--verbose'
check "log lines on the tab" panel_has telegram 'class=log'
for q in tgcfd=off tgworker=off tgcftls=on tgpool=4 tglog=off; do panel "tab=telegram&$q" >/dev/null; done
check "advanced settings back to defaults" sh -c "[ \"\$(flint-tg args | wc -l)\" -le 4 ]"
check "update check answers" sh -c "flint-tg latest | grep -q 'v[0-9]'"
panel "tab=telegram&tg=off" >/dev/null
check "Telegram proxy turned off" fails pidof tg-ws-proxy
rm -f /tmp/flint-test-page

if [ -n "$(flint-node codes)" ]; then
	code="$(flint-node codes | head -n1)"
	check "copy opens the form" sh -c "wget -qO- 'http://127.0.0.1:81/cgi-bin/panel.cgi?pass=$pin&lang=ru&tab=own&copy=$code' | grep -c 'name=save value=.new.'"
	cur="$(flint-node current)"
	panel "tab=servers&node=$code" >/dev/null
	check "server switch" current_is "$code"
	panel "tab=servers&node=$cur" >/dev/null
fi

# Settings export and import: a round trip brings back what changed after the export.
n="$(flint-node codes | wc -l)"
panel "export=1" > /tmp/flint-test-settings.txt
check "export downloads a settings file" grep -q '^# Flint VPN settings' /tmp/flint-test-settings.txt
check "export has no flint.env" fails grep -q '^\[flint.env\]' /tmp/flint-test-settings.txt
flint-node site add proxy zz-import-test.example >/dev/null 2>&1
curl -s -m 120 -F "file=@/tmp/flint-test-settings.txt;type=text/plain" \
	"http://127.0.0.1:81/cgi-bin/panel.cgi?pass=$pin&lang=ru&tab=settings&import=1" > /tmp/flint-test-page
check "import through the panel reports success" grep -q 'Настройки загружены' /tmp/flint-test-page
check "import brings back the exported sites" fails sh -c "flint-node site list | grep -q zz-import-test"
check "import keeps the servers" [ "$(flint-node codes | wc -l)" = "$n" ]
check "import rejects a foreign file" fails sh -c "echo hello | flint-settings import"
check "import rejects an unsafe section" fails sh -c "printf '# Flint VPN settings\n[../../etc/passwd]\n|x\n' | flint-settings import"
check "a rejected import changes nothing" [ "$(flint-node codes | wc -l)" = "$n" ]
rm -f /tmp/flint-test-settings.txt /tmp/flint-test-page
finish
