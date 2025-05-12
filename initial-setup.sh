#!/bin/bash
# initial-setup.sh

# Exit on error
set -e

echo "Installing doas and git..."
sudo xbps-install -Sy doas git

# Configure doas
echo "permit :wheel" | sudo tee /etc/doas.conf
sudo chmod 0400 /etc/doas.conf

# Make sure user is in appropriate groups
USERNAME=$(whoami)
sudo usermod -aG wheel "$USERNAME"

echo "Cloning the main setup repository..."
git clone https://github.com/yourusername/void-dwl-setup.git ~/void-dwl-setup
cd ~/void-dwl-setup

# Make the main script executable
chmod +x install.sh

echo "Initial setup complete! Now run: ~/void-dwl-setup/install.sh"
