#!/bin/bash

# Globális változók
INSTALL_DIR="$HOME/pyload"
VENV_DIR="$INSTALL_DIR/.venv"
CONFIG_DIR="$INSTALL_DIR/config"
DOWNLOADS_DIR="$HOME/Downloads/pyload"
LOG_DIR="$INSTALL_DIR/logs"

# Funkció a szabad port kereséséhez
function find_free_port() {
    LOW_BOUND=10001
    UPPER_BOUND=20000
    comm -23 <(seq "${LOW_BOUND}" "${UPPER_BOUND}" | sort) <(ss -Htan | awk '{print $4}' | cut -d':' -f2 | sort -u) | shuf | head -n 1
}

# Telepítési műveletek
function install_pyload() {
    echo "Starting PyLoad installation..."
    PORT=$(find_free_port)
    echo "Selected port for PyLoad: $PORT"

    mkdir -p "$INSTALL_DIR" "$DOWNLOADS_DIR" "$LOG_DIR"
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install wheel setuptools
    git clone https://github.com/pyload/pyload.git "$INSTALL_DIR/pyload"
    cd "$INSTALL_DIR/pyload"
    pip install -r requirements.txt

    # Konfigurációs fájl létrehozása
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_DIR/pyload.conf" <<EOF
version: 1

webinterface - "Webinterface":
    bool activated : "Activated" = True
    bool basicauth : "Use basic auth" = False
    ip host : "IP" = 0.0.0.0
    bool https : "Use HTTPS" = False
    int port : "Port" = $PORT
    str prefix : "Path Prefix" =
    builtin;threaded;fastcgi;lightweight server : "Server" = builtin
    modern;pyplex;classic template : "Template" = modern

general - "General":
    folder download_folder : "Download Folder" = $DOWNLOADS_DIR
EOF

    # Systemd unit fájl létrehozása a felhasználói szinten
    mkdir -p "$HOME/.config/systemd/user"
    cat > "$HOME/.config/systemd/user/pyload.service" <<EOF
[Unit]
Description=PyLoad

[Service]
Type=simple
User=$(whoami)
ExecStart=$VENV_DIR/bin/python $INSTALL_DIR/pyload/pyLoadCore.py --configdir=$CONFIG_DIR

[Install]
WantedBy=default.target
EOF

    # Systemd szolgáltatás engedélyezése és indítása
    systemctl --user daemon-reload
    systemctl --user enable --now pyload.service

    echo "PyLoad has been installed and started successfully."
    echo "Access it at http://localhost:$PORT"
}

# Eltávolítási műveletek
function uninstall_pyload() {
    echo "Starting PyLoad uninstallation..."
    # Systemd szolgáltatás megállítása és eltávolítása
    systemctl --user stop pyload.service
    systemctl --user disable pyload.service
    rm -f "$HOME/.config/systemd/user/pyload.service"
    systemctl --user daemon-reload
    systemctl --user reset-failed

    # Telepítési, konfigurációs és log könyvtárak törlése
    rm -rf "$INSTALL_DIR" "$CONFIG_DIR" "$LOG_DIR" "$VENV_DIR"
    # Letöltési könyvtár törlése opcionálisan
    # rm -rf "$DOWNLOADS_DIR"

    echo "PyLoad has been successfully uninstalled."
}

# Parancsok kezelése
if [ "$#" -ne 1 ]; then
    echo "This script expects an argument: 'install' or 'uninstall'"
    exit 1
fi

case "$1" in
    install)
        install_pyload
        ;;
    uninstall)
        uninstall_pyload
        ;;
    *)
        echo "Invalid argument: $1"
        echo "Usage: $0 {install|uninstall}"
        exit 1
        ;;
esac
