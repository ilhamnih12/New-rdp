#!/bin/bash

echo "[✔] Updating system and installing required packages..."
sudo apt update && sudo apt install -y wget curl unzip sudo xfce4 xfce4-goodies xrdp firefox git

echo "[✔] Creating RDP user..."
sudo useradd -m rdpuser || echo "User already exists"
echo "rdpuser:rdppass" | sudo chpasswd
sudo adduser rdpuser sudo

echo "[✔] Configuring xrdp to use XFCE..."
sudo sed -i.bak '/^test -x \/etc\/X11\/Xsession && exec \/etc\/X11\/Xsession/s/^/#/' /etc/xrdp/startwm.sh
sudo sed -i '/^exec \/bin\/sh \/etc\/X11\/Xsession/s/^/#/' /etc/xrdp/startwm.sh
echo "startxfce4" | sudo tee -a /etc/xrdp/startwm.sh

echo "[✔] Restarting xrdp service..."
sudo systemctl restart xrdp

echo "[✔] Starting Pinggy tunnel..."
ssh -o StrictHostKeyChecking=no -p 443 -R0:localhost:3389 tcp@free.pinggy.io
