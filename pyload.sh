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

echo 'This is unsupported software. You will not get help with this, please answer `yes` if you understand and wish to proceed'
read -r eula

if ! [[ $eula =~ yes ]]; then
  echo "You did not accept the above. Exiting..."
  exit 1
else
  echo "Proceeding with installation/uninstallation"
fi

echo "Welcome to the PyLoad installer..."
echo ""
echo "What would you like to do?"
echo "Logs are stored in ${LOG_DIR}"
echo "install = Install PyLoad"
echo "uninstall = Completely removes PyLoad"
echo "exit = Exits Installer"
while true; do
    read -r -p "Enter it here: " choice
    case $choice in
        "install")
            install_pyload
            break
            ;;
        "uninstall")
            uninstall_pyload
            break
            ;;
        "exit")
            echo "Exiting installer."
            break
            ;;
        *)
            echo "Unknown option. Please enter 'install', 'uninstall', or 'exit'."
            ;;
    esac
done
exit
