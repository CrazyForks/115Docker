#!/bin/bash
set +e

export HOME=${HOME:-/root}
export XDG_CONFIG_HOME="${HOME}/.config"
export DISPLAY_WIDTH=${DISPLAY_WIDTH:-1366}
export DISPLAY_HEIGHT=${DISPLAY_HEIGHT:-768}

VNC_PORT=$((5900 + ${DISPLAY#:}))
UI_JS_PATH="${NO_VNC_HOME}/app/ui.js"
COOKIE_FILE="/usr/local/115Cookie/worker.js"

mkdir -p "${HOME}/.vnc" \
         "${HOME}/.config/tint2" \
         "${HOME}/.config/pcmanfm/default" \
         "${HOME}/Desktop" \
         "${HOME}/Templates"

touch "${HOME}/.Xauthority"

rm -rf /tmp/.X11-unix/X${DISPLAY#:} "/tmp/.X${DISPLAY#:}-lock" "${HOME}/.vnc/*.pid" "${HOME}/.vnc/*.log"
rm -rf /etc/115/SingletonLock /etc/115/SingletonSocket /etc/115/SingletonCookie

TINT2_CONF="${HOME}/.config/tint2/tint2rc"
cat > "$TINT2_CONF" <<EOF
panel_items = TSC
panel_size = 100% 30
panel_margin = 0 0
panel_padding = 0 0 0
panel_background_id = 1
wm_menu = 1
panel_dock = 0
panel_layer = top

rounded = 0
border_width = 0
background_color = #282c34 100
border_color = #ffffff 0

taskbar_mode = single_desktop
taskbar_padding = 5 0 5
taskbar_background_id = 0
taskbar_active_background_id = 2
task_icon_asb = 100 0 0

rounded = 2
border_width = 0
background_color = #3e4452 100
border_color = #ffffff 0

time1_format = %H:%M
time1_font = Sans 10
time2_format = %Y-%m-%d
time2_font = Sans 8
clock_font_color = #ffffff 100
clock_padding = 10 0
clock_background_id = 0

systray_padding = 5 0 5
systray_icon_size = 20
systray_background_id = 0
EOF

cat > "${HOME}/.config/pcmanfm/default/desktop-items-0.conf" <<EOF
[*]
wallpaper_mode=color
desktop_bg=#282c34
desktop_fg=#ffffff
show_wm_menu=1
EOF

if [ -f "$COOKIE_FILE" ]; then
    EXPIRATION=$(date -d "+1 year" +%s)
    sed -i \
        -e "s|\(CID:\s*'\)[^']*'|\1$COOKIE_CID'|" \
        -e "s|\(SEID:\s*'\)[^']*'|\1$COOKIE_SEID'|" \
        -e "s|\(UID:\s*'\)[^']*'|\1$COOKIE_UID'|" \
        -e "s|\(KID:\s*'\)[^']*'|\1$COOKIE_KID'|" \
        -e "s|\(EXPIRATION_DATE:\s*\)[0-9]*|\1$EXPIRATION|" \
        "$COOKIE_FILE"
fi

echo "geometry=${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}" > "${HOME}/.vnc/config"

if [ -n "${PASSWORD}" ]; then
    export PASSWD_PATH="${HOME}/.vnc/passwd"
    echo "${PASSWORD}" | vncpasswd -f >"${PASSWD_PATH}"
    chmod 0600 "${PASSWD_PATH}"
    echo "securitytypes=VncAuth" >> "${HOME}/.vnc/config"
    [ -f "${UI_JS_PATH}" ] && sed -i "s/UI.initSetting('autoconnect', true);/UI.initSetting('autoconnect', false);/g" "${UI_JS_PATH}"
else
    echo "securitytypes=None" >> "${HOME}/.vnc/config"
    if [ -f "${UI_JS_PATH}" ]; then
        sed -i "s/UI.initSetting('autoconnect', false);/UI.initSetting('autoconnect', true);/g" "${UI_JS_PATH}"
        sed -i "s/getConfigVar('autoconnect', false)/getConfigVar('autoconnect', true)/g" "${UI_JS_PATH}"
    fi
fi

echo "Starting noVNC on port ${WEB_PORT}..."
"${NO_VNC_HOME}"/utils/novnc_proxy --vnc localhost:${VNC_PORT} --listen ${WEB_PORT} &

echo "Starting VNC Server on ${DISPLAY}..."
/usr/libexec/vncserver ${DISPLAY} &

echo "Waiting for X Server..."
for i in {1..20}; do
    if [ -S "/tmp/.X11-unix/X${DISPLAY#:}" ]; then
        echo "X Server is ready."
        break
    fi
    sleep 0.2
done

pcmanfm --desktop --profile default &

echo "Starting tint2..."
G_SLICE=always-malloc tint2 -c "$TINT2_CONF" &

echo "Starting 115 Browser..."
/usr/local/115Browser/115.sh
wait
