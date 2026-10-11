# SPDX-FileCopyrightText: 2026 Andrey Tokarev
# SPDX-License-Identifier: LicenseRef-Flint-VPN-Noncommercial-1.0
# The subs tab of the panel: this body runs inside the case of panel.cgi.
  if [ -n "$subedit" ]; then
    IFS="$TAB" read -r s_id s_name s_host s_st s_info <<EOF
$(flint-sub-update list | awk -F "$TAB" -v i="$subedit" '$1 == i')
EOF
    if [ -n "$s_id" ]; then
      s_url="$(flint-sub-update url "$s_id")"
      # After a failed save keep what was typed.
      [ -n "$subsave" ] && { s_url="$(param subu)"; s_name="$(param subn)"; }
      echo "<div class=card><h2>$(T "Изменить подписку" "Edit subscription")</h2>"
      echo "<form method=get>$(hidden)<input type=hidden name=subsave value='$s_id'>"
      field "$(T "Ссылка" "Link")" subu "$s_url" " required"
      field "$(T "Название" "Name")" subn "$s_name" " maxlength=60"
      echo "<button class=on style='margin-top:12px'>$(T "Сохранить" "Save")</button></form>"
      echo "<form method=get class=act>$(hidden)<button>$(T "Отмена" "Cancel")</button></form></div>"
    fi
  fi
  DEL="$(T "Удалить" "Delete")"; EDIT="$(T "Изменить" "Edit")"
  ASK="$(T "Удалить подписку и её серверы?" "Delete the subscription and its servers?")"
  echo "<div class=card><h2>$(T "Подписки" "Subscriptions")</h2><small>$(T "Ссылки на подписки любых VPN-провайдеров в формате v2rayN / Happ / Hiddify: список vless://, обычный или в base64. Серверы всех подписок появятся на вкладке «Серверы»." \
    "Subscription links from any VPN providers in the v2rayN / Happ / Hiddify format: a list of vless:// links, plain or base64. Servers from all subscriptions appear on the Servers tab.")</small>"
  [ -n "$SUBLIST" ] || echo "<p><small>$(T "пока нет" "none yet")</small></p>"
  echo "$SUBLIST" | while IFS="$TAB" read -r id sname host st info; do
    [ -n "$id" ] || continue
    [ "$st" = - ] && st="$(T "ещё не обновлялась" "not updated yet")"
    [ "$info" = - ] && info="" || info="<br><small>$info</small>"
    echo "<div class=item><span>$sname<br><small>$host · $st</small>$info</span>"
    echo "<form method=get>$(hidden)<input type=hidden name=subedit value='$id'><button>$EDIT</button></form>"
    echo "<form method=get onsubmit=\"return confirm('$ASK')\">$(hidden)<input type=hidden name=subdel value='$id'><button title='$DEL'>✕</button></form></div>"
  done
  echo "<form method=get class=row>$(hidden)<input type=text name=subadd placeholder='https://provider.example/sub/...' required>"
  echo "<input type=text name=subname placeholder='$(T "Название (необязательно)" "Name (optional)")'><button>$(T "Добавить подписку" "Add subscription")</button></form></div>"
  echo "<div class=card><h2>$(T "Обновление" "Updates")</h2>"
  btn sub 1 "" "$(T "Обновить все подписки сейчас" "Update all subscriptions now")"
  CHECKED="$(flint-sub-update status | esc)"
  echo "<small>$(T "Последняя проверка" "Last check"): ${CHECKED:-$NEVER}</small>"
  SI="$(flint-sub-update interval)"
  echo "<form method=get class=row>$(hidden)<select name=subint>"
  for v in "off:$(T "Автообновление выключено" "Auto-update off")" "30m:$(T "Обновлять каждые 30 минут" "Update every 30 minutes")" \
    "1h:$(T "Обновлять каждый час" "Update every hour")" "3h:$(T "Обновлять каждые 3 часа" "Update every 3 hours")" \
    "6h:$(T "Обновлять каждые 6 часов" "Update every 6 hours")" "12h:$(T "Обновлять каждые 12 часов" "Update every 12 hours")" \
    "24h:$(T "Обновлять раз в сутки" "Update once a day")"; do
    sel=""; [ "${v%%:*}" = "$SI" ] && sel=" selected"
    echo "<option value='${v%%:*}'$sel>${v#*:}</option>"
  done
  echo "</select><button>$(T "Сохранить" "Save")</button></form>"
  echo "<small>$(T "Если подписка не скачалась, её серверы остаются прежними." "If a subscription fails to download, its servers stay as they were.")</small></div>"
