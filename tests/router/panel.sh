# Panel actions through panel.cgi: every tab renders, each request runs exactly the action it names.
. "$(dirname "$0")/lib.sh"
echo "== panel: tabs and actions"
save_state
pin="$(sed -n 's/^UI_PIN=//p' /etc/xray/flint.env | tr -d '"')"
# panel <query>: the Russian page for the query (without pass and lang).
panel() { wget -qO- "http://127.0.0.1:81/cgi-bin/panel.cgi?pass=$pin&lang=ru&$1"; }
page_ok() { panel "$1" | grep -c '</html>'; }
for t in status servers own subs routing adblock dns settings; do check "tab $t renders" page_ok "tab=$t"; done
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
panel "tab=dns&dnsmode=doh" >/dev/null
check "mode switch back to DoH keeps its server" [ "$(flint-dns mode):$(flint-dns doh)" = doh:https://dns.google/dns-query ]
check "DNS answers after the mode switch" dns_answers
flint-dns udp "$udp" >/dev/null 2>&1; flint-dns dnscrypt "$dnscrypt" >/dev/null 2>&1
flint-dns doh "$doh" >/dev/null 2>&1; flint-dns mode "$dns_mode" >/dev/null 2>&1
check "DNS restored after the test" [ "$(flint-dns title)" = "$dns_title" ]
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
