#!/bin/bash
# install.sh - Main installation script for Void Linux with dwl

# Exit on error
set -e

# Function to check if running on Void Linux
check_void() {
  if [ ! -f /etc/void-release ] && ! command -v xbps-install >/dev/null 2>&1; then
    echo "Error: This script is designed for Void Linux."
    exit 1
  fi
}

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Ensure sudo is available
if ! command_exists sudo; then
  echo "Error: sudo is not available. Please install sudo and try again."
  exit 1
fi

SUDO="sudo"

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

# Setup additional repositories if needed
setup_repos() {
  if lspci | grep -i nvidia >/dev/null 2>&1; then
    echo "NVIDIA GPU detected, adding nonfree repository..."
    install_pkg void-repo-nonfree
    install_pkg nvidia
  else
    install_pkg void-repo-nonfree
  fi

  if [ "$(uname -m)" = "x86_64" ]; then
    echo "Adding multilib repository for 64-bit system..."
    install_pkg void-repo-multilib
  fi

  $SUDO xbps-install -S
}

# Function to build dwl from source if desired
build_dwl() {
  echo "Building dwl from source..."
  cd /tmp
  git clone https://github.com/djpohly/dwl.git
  cd dwl
  
  if [ -f ~/void-dwl-setup/configs/dwl/config.h ]; then
    cp ~/void-dwl-setup/configs/dwl/config.h .
  fi
  
  make
  $SUDO make install
  cd ~
}

# Function to install dwl-specific scripts
install_dwl_scripts() {
  mkdir -p ~/.local/bin
  cat > ~/.local/bin/dwl-tags.sh << 'EOF'
#!/bin/sh
echo '[{"name":"1","state":"focused"},{"name":"2","state":"inactive"}]'
EOF
  chmod +x ~/.local/bin/dwl-tags.sh
}

# Function to copy and adapt configs
setup_configs() {
  echo "Setting up configuration files..."
  mkdir -p ~/.config/waybar ~/.config/wofi ~/.config/alacritty ~/.config/dwl

  if [ -d ~/void-dwl-setup/configs/waybar ]; then
    if [ -f ~/void-dwl-setup/configs/waybar/config ]; then
      sed -e 's/"sway\/workspaces"/{"custom\/dwl-tags"}/' \
          -e 's/"sway\/mode"//' \
          ~/void-dwl-setup/configs/waybar/config > ~/.config/waybar/config

      if ! grep -q "custom/dwl-tags" ~/.config/waybar/config; then
        cat >> ~/.config/waybar/config << 'EOF'
    "custom/dwl-tags": {
        "exec": "~/.local/bin/dwl-tags.sh",
        "format": "{}",
        "return-type": "json",
        "interval": 1
    },
EOF
      fi
    fi

    cp -r ~/void-dwl-setup/configs/waybar/style.css ~/.config/waybar/ 2>/dev/null || true
  fi

  [ -d ~/void-dwl-setup/configs/wofi ] && cp -r ~/void-dwl-setup/configs/wofi/* ~/.config/wofi/ 2>/dev/null || true
  [ -d ~/void-dwl-setup/configs/alacritty ] && cp -r ~/void-dwl-setup/configs/alacritty/* ~/.config/alacritty/ 2>/dev/null || true

  if [ -d ~/void-dwl-setup/configs/greetd ]; then
    if [ -f ~/void-dwl-setup/configs/greetd/config.toml ]; then
      sed 's/command = ".*sway.*"/command = "tuigreet --cmd dwl"/' \
          ~/void-dwl-setup/configs/greetd/config.toml > /tmp/config.toml
    else
      cat > /tmp/config.toml << EOF
[terminal]
vt = 1

[default_session]
command = "tuigreet --cmd dwl"
user = "greeter"
EOF
    fi
    $SUDO mv /tmp/config.toml /etc/greetd/config.toml
    $SUDO chmod 644 /etc/greetd/config.toml
  fi

  for file in ~/.bash_profile ~/.zprofile; do
    if [ ! -f "$file" ] || ! grep -q "XDG_CURRENT_DESKTOP=dwl" "$file"; then
      cat >> "$file" << 'EOF'

# Wayland/dwl environment variables
export XDG_CURRENT_DESKTOP=dwl
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM=wayland
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export GDK_BACKEND=wayland
EOF
    fi
  done
}

# Begin main script
echo "=== Starting Void Linux + dwl Installation ==="
check_void
USERNAME=$(whoami)

echo "=== Setting up repositories ==="
setup_repos

echo "=== Installing System Foundations ==="
for pkg in xdg-desktop-portal-wlr dbus polkit seatd acpi chrony; do
  install_pkg "$pkg"
done

$SUDO usermod -a -G _seatd "$USERNAME"
enable_service dbus
enable_service seatd
enable_service chronyd

echo "=== Installing dwl Dependencies ==="
for pkg in libX11-devel libXft-devel libXinerama-devel wayland-protocols wayland-devel wlroots-devel freetype-devel; do
  install_pkg "$pkg"
done

echo "=== Installing Window System ==="
if xbps-query -Rs dwl >/dev/null 2>&1; then
  install_pkg dwl
else
  install_pkg git
  install_pkg base-devel
  build_dwl
fi

for pkg in greetd tuigreet waybar wofi wl-clipboard mako swaylock swayidle; do
  install_pkg "$pkg"
done

install_dwl_scripts
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
if xbps-query -S void-repo-nonfree >/dev/null 2>&1; then
  [ ! -e "/usr/bin/google-chrome" ] && install_pkg google-chrome || echo "Google Chrome already installed, skipping."
fi

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

install_pkg flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

echo "=== Installing Flatpak Applications ==="
for app in md.obsidian.Obsidian net.ankiweb.Anki com.discordapp.Discord us.zoom.Zoom; do
  flatpak list | grep -q "$app" || flatpak install -y flathub "$app"
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

setup_configs

echo "=== Installation Complete! ==="
cat << 'EOF'

Important dwl keyboard shortcuts (default):
- Alt+Shift+Return: Open terminal 
- Alt+p: Open wofi launcher
- Alt+Shift+c: Close focused window
- Alt+j/k: Focus next/previous window
- Alt+Shift+q: Quit dwl

To customize dwl, edit ~/.config/dwl/config.h and recompile:
  cd /path/to/dwl
  make
  sudo make install

For issues with your setup, check:
- Service status: sv status seatd
- Log messages: tail -f /var/log/messages

You may need to reboot your system to ensure all services start properly:
  sudo reboot

EOF
