# vless:// share links (one per line, run under LC_ALL=C) -> TSV:
#   status host port uuid sni pbk sid flag name
# status: "ok" for TCP + REALITY (+ xtls-rprx-vision), otherwise the reason it is unsupported.
# flag: two-letter country code from the flag emoji at the start of the name.
# Empty fields are "-" so a shell "read" with IFS=TAB keeps the columns; name stays last and
# has %XX turned into \0ooo escapes for the shell printf %b.
BEGIN { for (i = 1; i < 256; i++) ord[sprintf("%c", i)] = i; HEX = "0123456789ABCDEF" }
# Percent-encode raw non-ASCII bytes so names arrive in one form.
function pct(s,   i, c, out) {
	out = ""
	for (i = 1; i <= length(s); i++) { c = substr(s, i, 1); out = out (ord[c] > 127 ? sprintf("%%%02X", ord[c]) : c) }
	return out
}
function hexval(h) { h = toupper(h); return (index(HEX, substr(h, 1, 1)) - 1) * 16 + index(HEX, substr(h, 2, 1)) - 1 }
# %XX -> \0ooo for the shell printf %b.
function unpct(s,   out, x) {
	gsub(/\+/, " ", s); out = ""
	while ((x = index(s, "%")) > 0 && x + 2 <= length(s)) {
		out = out substr(s, 1, x - 1) sprintf("\\0%03o", hexval(substr(s, x + 1, 2))); s = substr(s, x + 3)
	}
	gsub(/\t/, " ", out)
	return out s
}
function param(q, k,   n, i, kv, p) {
	n = split(q, kv, "&")
	for (i = 1; i <= n; i++) { p = index(kv[i], "="); if (substr(kv[i], 1, p - 1) == k) return substr(kv[i], p + 1) }
	return ""
}
# Regional indicator pair (U+1F1E6..U+1F1FF = F0 9F 87 A6..BF) -> two-letter country code.
function flag(f,   u, x, i, c, out) {
	u = toupper(f); out = ""
	if (index(u, "%F0%9F%87%") != 1) return ""
	for (i = 0; i < 2; i++) {
		x = index(u, "%F0%9F%87%"); if (x == 0) return ""
		c = hexval(substr(u, x + 10, 2)) - 166; u = substr(u, x + 12)
		if (c < 0 || c > 25) return ""
		out = out substr("abcdefghijklmnopqrstuvwxyz", c + 1, 1)
	}
	return out
}
function d(s) { return s == "" ? "-" : s }
/^vless:\/\// {
	s = substr($0, 9)
	frag = ""; h = index(s, "#"); if (h) { frag = pct(substr(s, h + 1)); s = substr(s, 1, h - 1) }
	q = ""; h = index(s, "?"); if (h) { q = substr(s, h + 1); s = substr(s, 1, h - 1) }
	sub(/\/$/, "", s)
	at = index(s, "@"); uuid = substr(s, 1, at - 1); hp = substr(s, at + 1)
	c = index(hp, ":"); host = c ? substr(hp, 1, c - 1) : hp; port = c ? substr(hp, c + 1) : 443
	type = param(q, "type"); sec = param(q, "security"); fl = param(q, "flow")
	sni = param(q, "sni"); pbk = param(q, "pbk"); sid = param(q, "sid")
	st = "ok"
	if (uuid == "" || host == "") st = "no address or id"
	else if (type != "" && type != "tcp") st = "transport " type
	else if (sec != "reality") st = "security " d(sec)
	else if (sni == "" || pbk == "") st = "no sni or pbk"
	else if (fl != "" && fl != "xtls-rprx-vision") st = "flow " fl
	print st "\t" d(host) "\t" d(port) "\t" d(uuid) "\t" d(sni) "\t" d(pbk) "\t" d(sid) "\t" d(flag(frag)) "\t" unpct(frag)
}
