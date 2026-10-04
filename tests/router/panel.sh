# Panel actions through panel.cgi: every tab renders, each request runs exactly the action it names.
. "$(dirname "$0")/lib.sh"
echo "== panel: tabs and actions"
save_state
pin="$(sed -n 's/^UI_PIN=//p' /etc/xray/flint.env | tr -d '"')"
# panel <query>: the Russian page for the query (without pass and lang).
panel() { wget -qO- "http://127.0.0.1:81/cgi-bin/panel.cgi?pass=$pin&lang=ru&$1"; }
page_ok() { panel "$1" | grep -q '</html>'; }
for t in status servers own subs routing adblock settings; do check "tab $t renders" page_ok "tab=$t"; done
check "no hidden action fields" fails sh -c "wget -qO- 'http://127.0.0.1:81/cgi-bin/panel.cgi?pass=$pin&tab=servers' | grep -q 'name=a '"
check "wrong PIN shows the login form" sh -c "wget -qO- 'http://127.0.0.1:81/cgi-bin/panel.cgi?pass=bad' | grep -q 'type=password'"
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
check "new PIN opens the panel" sh -c "wget -qO- 'http://127.0.0.1:81/cgi-bin/panel.cgi?pass=zzPinTest9&tab=settings' | grep -q 'name=pinold'"
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
check "site without blocking listed" sh -c "wget -qO- 'http://127.0.0.1:81/cgi-bin/panel.cgi?pass=$pin&tab=adblock' | grep -q '<span>zz-allow-test.example</span>'"
panel "tab=adblock&abrdel=%40%40%7C%7Czz-allow-test.example%5E" >/dev/null
check "site without blocking removed" fails sh -c "flint-adblock rule | grep -qF zz-allow-test"

if [ -n "$(flint-node codes)" ]; then
	code="$(flint-node codes | head -n1)"
	check "copy opens the form" sh -c "wget -qO- 'http://127.0.0.1:81/cgi-bin/panel.cgi?pass=$pin&lang=ru&tab=own&copy=$code' | grep -q 'name=save value=.new.'"
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
