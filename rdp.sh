#!/bin/bash
set -e # Keluar jika ada error

# --- Konfigurasi ---
RDP_USER="deepnote"
PINGGY_LOG_FILE="pinggy_rdp_output.log"

# --- 1. Update dan Instalasi Dependensi ---
echo "INFO: Updating packages and installing RDP, LXQt, VS Code, SSH..."
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
    wget curl software-properties-common apt-transport-https gnupg \
    lxqt-core lxqt-qtplugin openbox pcmanfm-qt qterminal dbus-x11 \
    xrdp openssh-client

# --- 2. Instal Visual Studio Code ---
echo "INFO: Installing Visual Studio Code..."
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
sudo apt-get update -qq
sudo apt-get install -yq code

# --- 3. Konfigurasi User RDP ---
echo "INFO: Setting up RDP user '$RDP_USER'..."
read -sp "Enter new RDP password for user '$RDP_USER': " RDP_PASSWORD
echo
if [ -z "$RDP_PASSWORD" ]; then echo "ERROR: Password cannot be empty. Exiting."; exit 1; fi
echo "$RDP_USER:$RDP_PASSWORD" | sudo chpasswd
echo "INFO: RDP Password for '$RDP_USER' set."

# --- 4. Konfigurasi XRDP untuk LXQt ---
echo "INFO: Configuring XRDP for LXQt..."
sudo mkdir -p /home/$RDP_USER && sudo chown $RDP_USER:$RDP_USER /home/$RDP_USER
echo 'exec startlxqt' | sudo -u $RDP_USER tee /home/$RDP_USER/.xsession > /dev/null
sudo adduser xrdp ssl-cert > /dev/null 2>&1 || true # Grup ssl-cert

# --- 5. Restart XRDP Service ---
echo "INFO: Restarting XRDP service..."
sudo mkdir -p /var/run/xrdp && sudo chown xrdp:xrdp /var/run/xrdp && sudo chmod 0755 /var/run/xrdp
sudo systemctl enable xrdp > /dev/null 2>&1
sudo systemctl restart xrdp
sleep 3 # Tunggu service start

if ! sudo ss -ltnp | grep -q ':3389'; then
    echo "ERROR: XRDP service failed to start or listen on port 3389."
    sudo journalctl -u xrdp -n 20 --no-pager
    exit 1
fi
echo "INFO: XRDP service is running on port 3389."

# --- 6. Start Pinggy Tunnel ---
PINGGY_SSH_CMD="ssh -p 443 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -N -R0:localhost:3389 -L4300:localhost:4300 tcp@free.pinggy.io"
echo "INFO: Starting Pinggy tunnel: $PINGGY_SSH_CMD"
nohup $PINGGY_SSH_CMD > "$PINGGY_LOG_FILE" 2>&1 &
PINGGY_PID=$!

echo "INFO: Waiting for Pinggy tunnel (max 45s)... Output in $PINGGY_LOG_FILE"
PINGGY_CONNECT_INFO=""
for i in {1..45}; do
    if grep -q -E "tcp://.*is forwarding to" "$PINGGY_LOG_FILE"; then
        PINGGY_CONNECT_INFO=$(grep -o -E 'tcp://[^ ]+' "$PINGGY_LOG_FILE" | head -n 1)
        break
    fi
    sleep 1
done

if [ -z "$PINGGY_CONNECT_INFO" ]; then
    echo "ERROR: Failed to get Pinggy URL. Check $PINGGY_LOG_FILE for details."
    cat "$PINGGY_LOG_FILE"
    kill $PINGGY_PID 2>/dev/null || true
    exit 1
fi

PINGGY_HOST_PORT=$(echo "$PINGGY_CONNECT_INFO" | sed 's_tcp://__')

# --- 7. Selesai ---
echo
echo "==================================================================="
echo " RDP Setup Complete! (LXQt + VS Code)"
echo "==================================================================="
echo " RDP Host:    $PINGGY_HOST_PORT"
echo " Username:    $RDP_USER"
echo " Password:    (yang Anda masukkan tadi)"
echo " Desktop:     LXQt"
echo " VS Code:     Installed (menu -> Development -> Visual Studio Code)"
echo "==================================================================="
echo " Pinggy Tunnel PID: $PINGGY_PID (Log: $PINGGY_LOG_FILE)"
echo " IMPORTANT: Keep this Deepnote terminal active!"
echo " To stop Pinggy: kill $PINGGY_PID"
echo "==================================================================="

if ! ps -p $PINGGY_PID > /dev/null; then
   echo "WARNING: Pinggy SSH process (PID $PINGGY_PID) not found. Check $PINGGY_LOG_FILE."
fi
