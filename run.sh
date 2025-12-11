#!/bin/bash

DISPLAY_WIDTH=${DISPLAY_WIDTH:-1366}
DISPLAY_HEIGHT=${DISPLAY_HEIGHT:-768}
VNC_PORT=$((5900 + ${DISPLAY#:}))
UI_JS_PATH="${NO_VNC_HOME}/app/ui.js"
COOKIE_FILE="/usr/local/115Cookie/worker.js"

rm -rf /etc/115/SingletonLock /etc/115/SingletonSocket /etc/115/SingletonCookie
rm -rf /tmp/.X11-unix/X${DISPLAY#:} "/tmp/.X${DISPLAY#:}-lock" "${HOME}/.vnc/*.pid" "${HOME}/.vnc/*.log"

if [ -f "$COOKIE_FILE" ]; then
    EXPIRATION=$(date -d "+1 year" +%s)
    sed -i \
        -e "s/\(CID:\s*'\)[^']*'/\1$COOKIE_CID'/" \
        -e "s/\(SEID:\s*'\)[^']*'/\1$COOKIE_SEID'/" \
        -e "s/\(UID:\s*'\)[^']*'/\1$COOKIE_UID'/" \
        -e "s/\(KID:\s*'\)[^']*'/\1$COOKIE_KID'/" \
        -e "s/\(EXPIRATION_DATE:\s*\)[0-9]*/\1$EXPIRATION/" \
        "$COOKIE_FILE"
else
    echo "Warning: Cookie file $COOKIE_FILE not found."
fi

mkdir -p "${HOME}/.vnc"
echo "geometry=${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}" > "${HOME}/.vnc/config"

if [ -n "${PASSWORD}" ]; then
    export PASSWD_PATH="${HOME}/.vnc/passwd"
    echo "${PASSWORD}" | vncpasswd -f >"${PASSWD_PATH}"
    chmod 0600 "${PASSWD_PATH}"
    echo "securitytypes=VncAuth" >> "${HOME}/.vnc/config"
    
    if [ -f "${UI_JS_PATH}" ]; then
        sed -i "s/UI.initSetting('autoconnect', true);/UI.initSetting('autoconnect', false);/g" "${UI_JS_PATH}"
    fi
else
    echo "securitytypes=None" >> "${HOME}/.vnc/config"
    
    if [ -f "${UI_JS_PATH}" ]; then
        sed -i "s/UI.initSetting('autoconnect', false);/UI.initSetting('autoconnect', true);/g" "${UI_JS_PATH}"
    fi
fi

echo "Starting noVNC on port ${WEB_PORT}..."
"${NO_VNC_HOME}"/utils/novnc_proxy --vnc localhost:${VNC_PORT} --listen ${WEB_PORT} &

echo "Starting VNC Server on ${DISPLAY}..."
/usr/libexec/vncserver ${DISPLAY} &

for i in {1..10}; do
    if [ -S "/tmp/.X11-unix/X${DISPLAY#:}" ]; then
        break
    fi
    sleep 0.5
done

pcmanfm --desktop &

G_SLICE=always-malloc tint2 &

echo "Starting 115 Browser..."
/usr/local/115Browser/115.sh

wait
