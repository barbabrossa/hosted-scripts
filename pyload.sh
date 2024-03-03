#!/bin/bash

# Globális változók
INSTALL_DIR="$HOME/pyload"
VENV_DIR="$INSTALL_DIR/.venv"
DOWNLOADS_DIR="$HOME/Downloads/"
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
    pip install --pre pyload-ng[all]

    echo "PyLoad has been installed successfully."

    # Systemd unit fájl létrehozása a felhasználói szinten
    mkdir -p "$HOME/.config/systemd/user"
    cat > "$HOME/.config/systemd/user/pyload.service" <<EOF
[Unit]
Description=PyLoad
After=network.target

[Service]
Type=simple
User=$(whoami)
ExecStart=$VENV_DIR/bin/python $VENV_DIR/bin/pyload

[Install]
WantedBy=multi-user.target
EOF

    # Systemd szolgáltatás engedélyezése és indítása
    systemctl --user daemon-reload
    systemctl enable --user --now pyload.service

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
    rm -rf "$INSTALL_DIR" "$LOG_DIR" "$VENV_DIR"
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
