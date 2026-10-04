# Panel actions through panel.cgi: every tab renders, each request runs exactly the action it names.
. "$(dirname "$0")/lib.sh"
echo "== panel: tabs and actions"
save_state
pin="$(sed -n 's/^UI_PIN=//p' /etc/xray/flint.env | tr -d '"')"
# panel <query>: the Russian page for the query (without pass and lang).
panel() { wget -qO- "http://127.0.0.1:81/cgi-bin/panel.cgi?pass=$pin&lang=ru&$1"; }
page_ok() { panel "$1" | grep -q '</html>'; }
for t in status servers own subs routing adblock; do check "tab $t renders" page_ok "tab=$t"; done
check "no hidden action fields" fails sh -c "wget -qO- 'http://127.0.0.1:81/cgi-bin/panel.cgi?pass=$pin&tab=servers' | grep -q 'name=a '"
check "wrong PIN shows the login form" sh -c "wget -qO- 'http://127.0.0.1:81/cgi-bin/panel.cgi?pass=bad' | grep -q 'type=password'"

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
finish
