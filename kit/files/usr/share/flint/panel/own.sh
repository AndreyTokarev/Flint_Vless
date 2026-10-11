# SPDX-FileCopyrightText: 2026 Andrey Tokarev
# SPDX-License-Identifier: LicenseRef-Flint-VPN-Noncommercial-1.0
# The own tab of the panel: this body runs inside the case of panel.cgi.
  if [ -n "$form" ]; then
    [ "$form" = new ] && title="$(T "Новый сервер" "New server")" || title="$(T "Изменить сервер" "Edit server")"
    echo "<div class=card><h2>$title</h2><small>$(T "Поддерживаются VLESS + REALITY поверх TCP (xtls-rprx-vision) или gRPC." "Supported: VLESS + REALITY over TCP (xtls-rprx-vision) or gRPC.")</small>"
    echo "<form method=get>$(hidden)<input type=hidden name=save value='$form'>"
    field "$(T "Название" "Name")" n "$f_name" " maxlength=60"
    field "$(T "Адрес сервера" "Server address")" h "$f_addr" " required"
    field "$(T "Порт" "Port")" p "$f_port" " required inputmode=numeric"
    field "UUID" u "$f_uuid" " required"
    field "SNI (serverName)" s "$f_sni" " required"
    field "Public key (pbk)" k "$f_pbk" " required"
    field "Short ID (sid)" i "$f_sid" ""
    [ "$f_net" = grpc ] && g_sel=" selected" || g_sel=""
    echo "<label>$(T "Транспорт" "Transport")<select name=t style='width:100%;margin-top:4px'><option value=tcp>TCP (xtls-rprx-vision)</option><option value=grpc$g_sel>gRPC</option></select></label>"
    field "gRPC serviceName ($(T "только для gRPC" "gRPC only"))" g "$f_svc" ""
    echo "<button class=on style='margin-top:12px'>$(T "Сохранить" "Save")</button></form>"
    echo "<form method=get class=act>$(hidden)<button>$(T "Отмена" "Cancel")</button></form></div>"
  fi
  echo "<div class=card><h2>$(T "Свои серверы" "Own servers")</h2><small>$(T "Не из подписки: автообновление их не трогает. Выбираются на вкладке «Серверы»." "Not from the subscription: auto-update leaves them alone. Pick them on the Servers tab.")</small>"
  OWN="$(flint-custom list | esc)"
  [ -n "$OWN" ] || echo "<p><small>$(T "пока нет" "none yet")</small></p>"
  DEL="$(T "Удалить" "Delete")"; EDIT="$(T "Изменить" "Edit")"
  echo "$OWN" | while IFS="$TAB" read -r code name; do
    [ -n "$code" ] || continue
    echo "<div class=item><span>$name</span>"
    echo "<form method=get>$(hidden)<input type=hidden name=edit value='$code'><button>$EDIT</button></form>"
    echo "<form method=get>$(hidden)<input type=hidden name=ndel value='$code'><button title='$DEL'>✕</button></form></div>"
  done
  echo "</div><div class=card><h2>$(T "Добавить" "Add")</h2>"
  echo "<form method=get class=row>$(hidden)<input type=text name=link placeholder='vless://...' required><button>$(T "Добавить по ссылке" "Add by link")</button></form>"
  if [ -n "$NAMES" ]; then
    echo "<form method=get class=row>$(hidden)<select name=copy>"
    echo "$NAMES" | while IFS="$TAB" read -r code name kind group; do [ -n "$code" ] && echo "<option value='$code'>$name</option>"; done
    echo "</select><button>$(T "Скопировать и изменить" "Copy and edit")</button></form>"
  fi
  btn newnode 1 "" "$(T "Ввести вручную" "Enter manually")"
  echo "</div>"
