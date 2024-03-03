#!/bin/bash
# you have to start the program from the command line and then change the port of the webui in the config file
# program start: /home/user_name/pyload/.venv/bin/python3 /home/user_name/pyload/.venv/bin/pyload
# edit config: .pyload/settings/pyload.cfg in webui section -> ip host : "IP address" = 0.0.0.0 and int port : "Port" = $PORT
# when you enter the interface it is recommended to disable clicknload in the settings

INSTALL_DIR="$HOME/pyload"
VENV_DIR="$INSTALL_DIR/.venv"
DOWNLOADS_DIR="$HOME/Downloads/"
LOG_DIR="$INSTALL_DIR/logs"

function find_free_port() {
    LOW_BOUND=10001
    UPPER_BOUND=20000
    comm -23 <(seq "${LOW_BOUND}" "${UPPER_BOUND}" | sort) <(ss -Htan | awk '{print $4}' | cut -d':' -f2 | sort -u) | shuf | head -n 1
}


function install_pyload() {
    echo "Starting PyLoad installation..."
    PORT=$(find_free_port)
    echo "Selected port for PyLoad: $PORT"

    mkdir -p "$INSTALL_DIR" "$DOWNLOADS_DIR" "$LOG_DIR"
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --pre pyload-ng[all]

    echo "PyLoad has been installed successfully."

    # Systemd unit create
    mkdir -p "$HOME/.config/systemd/user"
    cat > "$HOME/.config/systemd/user/pyload.service" <<EOF
[Unit]
Description=PyLoad
After=network.target

[Service]
Type=simple
ExecStart=$VENV_DIR/bin/python $VENV_DIR/bin/pyload

[Install]
WantedBy=multi-user.target
EOF

    # Systemd szolgáltatás enable and start
    systemctl --user daemon-reload
    systemctl enable --user --now pyload.service

    echo "PyLoad has been installed and started successfully."
    echo "Access it at http://hostingby.design.server.url:$PORT"
}

function uninstall_pyload() {
    echo "Starting PyLoad uninstallation..."
    # Systemd szolgáltatás megállítása és eltávolítása
    systemctl --user stop pyload.service
    systemctl --user disable pyload.service
    rm -f "$HOME/.config/systemd/user/pyload.service"
    systemctl --user daemon-reload
    systemctl --user reset-failed

    rm -rf "$INSTALL_DIR" "$LOG_DIR" "$VENV_DIR"
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
