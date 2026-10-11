# Plan I.3: measure whether this network looks like a gateway with many parallel TLS connections to one
# SNI, which is what some carriers use to decide that a connection is worth freezing or throttling. The
# answer decides whether the transport wants to spread its connections (mux and similar) or not.
#
# Read-only: it only looks at the connection table and writes a log. Nothing is changed, no traffic is
# generated, and Xray is not touched — it is safe to run on a working router and to stop at any moment
# (Ctrl+C), including in the middle of the hour.
#
# Usage: sh tls_parallel.sh [minutes] [log]
#        sh tls_parallel.sh 60 /tmp/tls-parallel.log     (defaults: 60 minutes, that log)
#
# What it records every 10 seconds: how many connections to 443 there are in total, and for each server
# address the number of connections and the number of distinct devices behind them. The second number is the
# interesting one: several devices of the household reaching the same address at the same time is what a
# "many parallel connections" rule looks for.
#
# A conntrack line holds two tuples: the original one (the device to the server) and the reply. The server
# address is dst of the first tuple, the device is src of the first tuple; the second tuple is always the
# reverse and must not be counted, or every address appears twice.
#
# Reading the result:
#   tail -n 20 /tmp/tls-parallel.log          the last samples
#   awk '$4 > 3' /tmp/tls-parallel.log        every sample where one address had more than 3 devices
# The number after an address is its connections, then its devices.
# The finding belongs in docs/ as a measurement, not as a promise: it says what this network did during
# this hour, not what the carrier will do next week.
set -u
# Minutes, with fractions allowed so a short trial run is possible: "0.5" is half a minute.
MINUTES="${1:-60}"
LOG="${2:-/tmp/tls-parallel.log}"
STEP=10
END="$(awk -v m="$MINUTES" 'BEGIN { printf "%d", m * 60 }')"
[ "$END" -gt 0 ] 2>/dev/null || { echo "usage: sh tls_parallel.sh [minutes] [log]"; exit 1; }

# conntrack is part of the base system on the GL.iNet firmware; without it nothing can be measured.
command -v conntrack >/dev/null || { echo "conntrack is not installed: nothing to measure with"; exit 1; }

echo "# tls_parallel: started $(date '+%Y-%m-%d %H:%M'), duration ${MINUTES} min, step ${STEP}s" >> "$LOG"
echo "# time total  per server: address connections devices" >> "$LOG"

elapsed=0
while [ "$elapsed" -lt "$END" ]; do
	# One read of the table per sample: "conntrack -L" is not cheap on a small router.
	snapshot="$(conntrack -L -p tcp --dport 443 2>/dev/null)"
	total="$(printf '%s\n' "$snapshot" | grep -c .)"
	per="$(printf '%s\n' "$snapshot" | awk '
		{
			server = ""; device = ""
			for (i = 1; i <= NF; i++) {
				if ($i ~ /^dst=/ && server == "") { server = $i; sub(/^dst=/, "", server) }
				if ($i ~ /^src=/ && device == "") { device = $i; sub(/^src=/, "", device) }
			}
			# Only the networks that go out: a loopback or LAN-to-LAN pair is not a connection to a server.
			if (server == "" || server ~ /^(10\.|127\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)/) next
			conns[server]++
			if (device != "") dev[server "\t" device] = 1
		}
		END {
			for (d in dev) { split(d, p, "\t"); devices[p[1]]++ }
			for (s in conns) print s, conns[s], devices[s] + 0
		}' | sort -k3,3nr -k2,2nr | head -n 5 | tr '\n' ' ')"
	printf '%s %s %s\n' "$(date '+%H:%M:%S')" "$total" "$per" >> "$LOG"
	sleep "$STEP"
	elapsed=$((elapsed + STEP))
done

echo "# tls_parallel: finished $(date '+%Y-%m-%d %H:%M')" >> "$LOG"
echo "done: $LOG"
echo "worst case (devices behind one server address): $(awk '$1 !~ /^#/ && $2 ~ /^[0-9]+$/ { for (i = 4; i <= NF; i += 3) if ($i + 0 > m) m = $i + 0 } END { print m + 0 }' "$LOG")"
echo "see: awk '\$1 !~ /^#/ && \$4 > 3' $LOG"
