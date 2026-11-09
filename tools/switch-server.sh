#!/bin/sh
# Switch the VPN to the given server, check that traffic really passes, and go back if it does not.
# Runs detached (start-stop-daemon), so a dropped SSH or a broken tunnel of the machine that started it
# cannot leave the router on a dead server: the check and the rollback happen here, on the router.
LOG=/tmp/flint-switch.log
exec > "$LOG" 2>&1
target="$1"
prev="$(cat /etc/xray/current-node 2>/dev/null)"
echo "=== $(date '+%H:%M:%S') старт: был '$prev', переключаюсь на '$target'"
flint-node use "$target"
echo "--- flint-node use вернул $?"
sleep 2
ok=0
i=0
while [ "$i" -lt 4 ]; do
	i=$((i + 1))
	code="$(curl -s -m 6 -x http://127.0.0.1:1087 -o /dev/null -w '%{http_code}' https://www.gstatic.com/generate_204 2>/dev/null)"
	[ "$code" = 204 ] && ok=$((ok + 1))
	echo "--- проверка $i: код '$code'"
done
echo "--- успешных: $ok из 4"
if [ "$ok" -lt 2 ] && [ -n "$prev" ] && [ "$prev" != "$target" ]; then
	echo "--- мало успешных, откат на '$prev'"
	flint-node use "$prev"
	echo "--- откат вернул $?"
fi
echo "=== $(date '+%H:%M:%S') готово: сейчас '$(cat /etc/xray/current-node 2>/dev/null)'"
