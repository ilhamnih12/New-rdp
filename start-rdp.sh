#!/bin/bash

echo "[✔] Updating system and installing required packages..."
sudo apt update && sudo apt install -y wget curl unzip sudo xvfb x11vnc fluxbox wine64 xrdp git openssh-client

echo "[✔] Creating RDP user..."
sudo useradd -m rdpuser || echo "User already exists"
echo "rdpuser:rdppass" | sudo chpasswd
sudo adduser rdpuser sudo

echo "[✔] Starting X11 display..."
Xvfb :1 -screen 0 1024x768x16 &
export DISPLAY=:1

echo "[✔] Starting lightweight desktop..."
fluxbox &

echo "[✔] Starting VNC server..."
x11vnc -display :1 -nopw -forever &

echo "[✔] Starting xrdp service..."
sudo /etc/init.d/xrdp start

echo "[✔] Starting Pinggy tunnel..."
ssh -o StrictHostKeyChecking=no -p 443 -R0:localhost:3389 tcp@free.pinggy.io
