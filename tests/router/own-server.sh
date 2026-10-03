# From no servers: the first own server turns the VPN on, deleting it turns it off.
. "$(dirname "$0")/lib.sh"
echo "== own-server: first own server on an empty router"
save_state
line="$(first_node_line)"
if [ -z "$line" ]; then echo "  skip: the router has no servers to copy"; finish; exit; fi
go_empty
. /etc/xray/flint.env
set -- $line
flint-custom set new "Test" "$2" "${7:-443}" "${6:-$VLESS_UUID}" "$3" "$4" "${5:--}" "${8:-tcp}" "${9:--}" >/dev/null 2>&1
check "own server saved" [ "$(flint-custom list | cut -f1)" = my1 ]
check "own server is current" current_is my1
vpn_mode
flint-custom del my1 >/dev/null 2>&1
direct_mode
finish
