#!/usr/bin/env bash
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
TARGET="$CONFIG/quickshell/island"
AUTOSTART="$CONFIG/autostart/dynamic-island.desktop"
LOGGING="quickshell.dbus.properties.warning=false"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
ok() { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }

usage() {
    cat <<EOF
Dynamic Island для KDE Plasma

  ./install.sh              установить и запустить
  ./install.sh --autostart  то же + запуск при входе в систему
  ./install.sh --meta       то же + открытие «Приложений» по клавише Meta
  ./install.sh --run        только перезапустить остров
  ./install.sh --uninstall  удалить ссылку, автозапуск и привязку Meta
EOF
}

WANT_AUTOSTART=0
WANT_META=0
MODE=install
for arg in "$@"; do
    case "$arg" in
        --autostart) WANT_AUTOSTART=1 ;;
        --meta) WANT_META=1 ;;
        --run) MODE=run ;;
        --uninstall) MODE=uninstall ;;
        -h|--help) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done

run_island() {
    pkill -f "quickshell -p $TARGET" 2>/dev/null || true
    sleep 0.3
    QT_LOGGING_RULES="$LOGGING" setsid quickshell -p "$TARGET" >/dev/null 2>&1 < /dev/null &
    ok "остров запущен"
}

unbind_meta() {
    if command -v kwriteconfig6 >/dev/null; then
        kwriteconfig6 --file kwinrc --group ModifierOnlyShortcuts --key Meta --delete
        qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
    fi
}

if [ "$MODE" = run ]; then
    run_island
    exit 0
fi

if [ "$MODE" = uninstall ]; then
    bold "Удаление"
    pkill -f "quickshell -p $TARGET" 2>/dev/null || true
    if [ -L "$TARGET" ]; then rm "$TARGET"; ok "ссылка $TARGET удалена"; fi
    if [ -f "$AUTOSTART" ]; then rm "$AUTOSTART"; ok "автозапуск убран"; fi
    if [ "$(kreadconfig6 --file kwinrc --group ModifierOnlyShortcuts --key Meta 2>/dev/null)" = "org.dynamicisland.Cursor,/Cursor,org.dynamicisland.Cursor,OpenApps" ]; then
        unbind_meta
        ok "клавиша Meta возвращена Plasma"
    fi
    exit 0
fi

bold "Проверка зависимостей"
declare -A PKG=(
    [quickshell]=quickshell
    [cava]=cava
    [python3]=python-gobject
    [sqlite3]=sqlite
    [nmcli]=networkmanager
    [busctl]=systemd
    [dbus-monitor]=dbus
    [qdbus6]=qt6-tools
    [kreadconfig6]=kconfig
    [checkupdates]=pacman-contrib
    [konsole]=konsole
)
OPTIONAL=" checkupdates konsole "
missing=()
for cmd in "${!PKG[@]}"; do
    if command -v "$cmd" >/dev/null; then
        continue
    fi
    if [[ "$OPTIONAL" == *" $cmd "* ]]; then
        warn "$cmd не найден — плитка обновлений работать не будет"
    else
        missing+=("${PKG[$cmd]}")
    fi
done
if ! python3 -c "import gi" 2>/dev/null; then
    missing+=(python-gobject)
fi

if [ ${#missing[@]} -gt 0 ]; then
    mapfile -t missing < <(printf '%s\n' "${missing[@]}" | sort -u)
    warn "не хватает: ${missing[*]}"
    if command -v pacman >/dev/null; then
        printf '    установить сейчас через pacman? [Y/n] '
        read -r answer
        if [[ ! "$answer" =~ ^[Nn] ]]; then
            sudo pacman -S --needed "${missing[@]}"
        else
            exit 1
        fi
    else
        warn "установите эти пакеты менеджером вашего дистрибутива и запустите скрипт снова"
        exit 1
    fi
fi
ok "всё на месте"

bold "Установка"
mkdir -p "$(dirname "$TARGET")"
if [ -L "$TARGET" ] && [ "$(readlink -f "$TARGET")" = "$SRC" ]; then
    ok "ссылка уже указывает сюда"
else
    if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
        backup="$TARGET.bak-$(date +%Y%m%d-%H%M%S)"
        mv "$TARGET" "$backup"
        warn "старый конфиг перенесён в $backup"
    fi
    ln -s "$SRC" "$TARGET"
    ok "$TARGET → $SRC"
fi

if [ "$WANT_AUTOSTART" = 1 ]; then
    mkdir -p "$(dirname "$AUTOSTART")"
    cat > "$AUTOSTART" <<EOF
[Desktop Entry]
Type=Application
Name=Dynamic Island
Exec=env QT_LOGGING_RULES=$LOGGING quickshell -p $TARGET
X-KDE-autostart-phase=2
NoDisplay=true
EOF
    ok "автозапуск при входе включён"
fi

if [ "$WANT_META" = 1 ]; then
    kwriteconfig6 --file kwinrc --group ModifierOnlyShortcuts --key Meta "org.dynamicisland.Cursor,/Cursor,org.dynamicisland.Cursor,OpenApps"
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
    ok "Meta открывает «Приложения»"
fi

run_island
echo
bold "Готово. Наведите курсор на остров вверху экрана."
