#!/bin/bash

INSTALL_DIR="$HOME/.pyload"
VENV_DIR="$INSTALL_DIR/.venv"
DOWNLOADS_DIR="$HOME/Downloads/"
LOG_DIR="$INSTALL_DIR/logs"
CONFIG_FILE="$INSTALL_DIR/settings/pyload.cfg"
SYSTEMD_SERVICE="$HOME/.config/systemd/user/pyload.service"
DEFAULT_IP="0.0.0.0"

function find_free_port() {
    LOW_BOUND=10001
    UPPER_BOUND=20000
    comm -23 <(seq "${LOW_BOUND}" "${UPPER_BOUND}" | sort) <(ss -Htan | awk '{print $4}' | cut -d':' -f2 | sort -u) | shuf | head -n 1
}

function setup_systemd() {
    echo "Setting up systemd service..."
    mkdir -p "$(dirname "$SYSTEMD_SERVICE")"
    cat > "$SYSTEMD_SERVICE" <<EOF
[Unit]
Description=PyLoad
After=network.target

[Service]
Type=simple
ExecStart=$VENV_DIR/bin/python $VENV_DIR/bin/pyload

[Install]
WantedBy=multi-user.target
EOF

    systemctl --user daemon-reload
    systemctl enable --user --now pyload.service
    echo "Systemd service has been set up and started."
}

function remove_systemd() {
    echo "Removing systemd service..."
    systemctl --user stop pyload.service
    systemctl --user disable pyload.service
    rm -f "$SYSTEMD_SERVICE"
    systemctl --user daemon-reload
    systemctl --user reset-failed
    echo "Systemd service has been removed."
}

function create_virtualenv() {
    echo "Creating virtual environment..."
    if python3 -m venv "$VENV_DIR"; then
        source "$VENV_DIR/bin/activate"
        echo "Upgrading pip, setuptools, and wheel..."
        pip install --upgrade pip setuptools wheel

        echo "Checking for outdated packages..."
        OUTDATED_PACKAGES=$(pip list --outdated | grep -v 'Package' | awk '{print $1}')

        if [ -n "$OUTDATED_PACKAGES" ]; then
            echo "Upgrading all outdated packages..."
            echo "$OUTDATED_PACKAGES" | xargs -n1 pip install --upgrade
        else
            echo "No packages to upgrade."
        fi

        echo "Virtual environment and packages upgraded successfully."
    else
        echo "Error creating virtual environment. Exiting..."
        exit 1
    fi
}

function install_pyload() {
    echo "Starting PyLoad installation..."
    PORT=$(find_free_port)
    echo "Selected port for PyLoad: $PORT"

    mkdir -p "$INSTALL_DIR" "$DOWNLOADS_DIR" "$LOG_DIR"
    
    create_virtualenv

    if ! pip install --pre pyload-ng[all]; then
        echo "Error installing PyLoad. Exiting..."
        exit 1
    fi

    echo "PyLoad has been installed successfully."

    setup_systemd

    echo "Waiting for PyLoad to start..."
    sleep 5  # Wait for PyLoad to create necessary files

    echo "Stopping PyLoad service to modify configuration..."
    systemctl --user stop pyload.service

    # Update config file
    sed -i "/\[webui\]/,/\[/ s/ip host *=.*/ip host = $DEFAULT_IP/" "$CONFIG_FILE"
    sed -i "/\[webui\]/,/\[/ s/int port *=.*/int port = $PORT/" "$CONFIG_FILE"

    echo "PyLoad configuration has been updated."

    echo "Restarting PyLoad service..."
    systemctl --user start pyload.service

    echo "Access it at http://$(hostname -f):$PORT"
}

function uninstall_pyload() {
    echo "Starting PyLoad uninstallation..."
    remove_systemd
    rm -rf "$INSTALL_DIR" "$LOG_DIR" "$VENV_DIR"
    echo "PyLoad has been successfully uninstalled."
}

function upgrade_pyload() {
    echo "Starting PyLoad upgrade..."
    
    if [ ! -d "$VENV_DIR" ]; then
        echo "Virtual environment not found. Exiting..."
        exit 1
    fi
    
    source "$VENV_DIR/bin/activate"
    
    echo "Upgrading pip, setuptools, and wheel..."
    pip install --upgrade pip setuptools wheel
    
    echo "Checking for outdated packages..."
    OUTDATED_PACKAGES=$(pip list --outdated | grep -v 'Package' | awk '{print $1}')

    if [ -n "$OUTDATED_PACKAGES" ]; then
        echo "Upgrading all outdated packages..."
        echo "$OUTDATED_PACKAGES" | xargs -n1 pip install --upgrade
    else
        echo "No packages to upgrade."
    fi

    if ! pip install --upgrade pyload-ng[all]; then
        echo "Error upgrading PyLoad. Exiting..."
        exit 1
    fi
    
    echo "Restarting PyLoad service..."
    systemctl --user restart pyload.service
    echo "PyLoad service has been restarted."
}

echo 'This is unsupported software. You will not get help with this, please answer `yes` if you understand and wish to proceed. You are responsible for securing your software.'
read -r eula

if [[ $eula != "yes" ]]; then
  echo "You did not accept the above. Exiting..."
  exit 1
fi

echo "Proceeding with installation/uninstallation."
echo "Welcome to the PyLoad installer..."
echo ""
echo "What would you like to do?"
echo "Logs are stored in ${LOG_DIR}"
echo "install = Install PyLoad"
echo "upgrade = Upgrade PyLoad"
echo "uninstall = Completely remove PyLoad"
echo "exit = Exit Installer"
while true; do
    read -r -p "Enter your choice: " choice
    case $choice in
        "install")
            install_pyload
            break
            ;;
        "upgrade")
            upgrade_pyload
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
            echo "Unknown option. Please enter 'install', 'upgrade', 'uninstall', or 'exit'."
            ;;
    esac
done
exit
