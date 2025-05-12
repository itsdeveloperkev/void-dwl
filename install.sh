#!/bin/bash
# install.sh - Main installation script

# Exit on error
set -e

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check for doas or sudo
if command_exists doas; then
  SUDO="doas"
elif command_exists sudo; then
  SUDO="sudo"
else
  echo "Error: Neither doas nor sudo is available. Install one first."
  exit 1
fi

# Function to install a package if not already installed
install_pkg() {
  if ! xbps-query -S "$1" >/dev/null 2>&1; then
    echo "Installing $1..."
    $SUDO xbps-install -y "$1"
  else
    echo "$1 already installed, skipping."
  fi
}

# Function to enable a service if not already enabled
enable_service() {
  if [ ! -e "/var/service/$1" ]; then
    echo "Enabling $1 service..."
    $SUDO ln -s "/etc/sv/$1" "/var/service/"
  else
    echo "Service $1 already enabled, skipping."
  fi
}

# Get username
USERNAME=$(whoami)

echo "=== Installing System Foundations ==="
for pkg in xdg-desktop-portal-wlr dbus polkit seatd acpi chrony; do
  install_pkg "$pkg"
done

# Add user to _seatd group
$SUDO usermod -a -G _seatd "$USERNAME"

# Enable essential services
enable_service dbus
enable_service seatd
enable_service chronyd

echo "=== Installing Window System ==="
for pkg in dwl greetd tuigreet waybar wofi wl-clipboard mako swaylock swayidle; do
  install_pkg "$pkg"
done

enable_service greetd

echo "=== Installing Terminal & Tools ==="
for pkg in alacritty fastfetch htop; do
  install_pkg "$pkg"
done

echo "=== Installing Audio/Video ==="
for pkg in pipewire wireplumber pavucontrol; do
  install_pkg "$pkg"
done

echo "=== Installing Document/Study Tools ==="
for pkg in zathura zathura-pdf-poppler xournalpp libreoffice-calc taskwarrior calcurse; do
  install_pkg "$pkg"
done

echo "=== Installing Browsers & Communication ==="
install_pkg chromium

echo "=== Installing File Management ==="
for pkg in pcmanfm gvfs p7zip unzip unrar; do
  install_pkg "$pkg"
done

echo "=== Installing Media Tools ==="
for pkg in mpv imv gimp grim slurp; do
  install_pkg "$pkg"
done

echo "=== Installing Development Tools ==="
for pkg in git flatpak vscodium micro gcc make; do
  install_pkg "$pkg"
done

# Set up Flatpak
install_pkg flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

echo "=== Installing Flatpak Applications ==="
for app in md.obsidian.Obsidian net.ankiweb.Anki com.discordapp.Discord us.zoom.Zoom; do
  if ! flatpak list | grep -q "$app"; then
    flatpak install -y flathub "$app"
  else
    echo "$app already installed via Flatpak, skipping."
  fi
done

echo "=== Installing Networking ==="
for pkg in NetworkManager NetworkManager-openvpn; do
  install_pkg "$pkg"
done
enable_service NetworkManager

echo "=== Installing Utilities ==="
install_pkg tlp
install_pkg rsync
enable_service tlp

echo "=== Configuring greetd with tuigreet ==="
# Backup existing config if it exists
if [ -f /etc/greetd/config.toml ]; then
  $SUDO cp /etc/greetd/config.toml /etc/greetd/config.toml.bak
fi

# Create the tuigreet config
cat > /tmp/config.toml << EOF
[terminal]
vt = 1

[default_session]
command = "tuigreet --cmd dwl"
user = "greeter"
EOF

$SUDO mv /tmp/config.toml /etc/greetd/config.toml
$SUDO chmod 644 /etc/greetd/config.toml

echo "=== Setting up system configurations ==="
# Create directories for configs if they don't exist
mkdir -p ~/.config/dwl

echo "=== Installation Complete! ==="
echo "You may need to reboot your system to ensure all services start properly."
echo "After reboot, you should be greeted with tuigreet and can log in to your dwl session."
