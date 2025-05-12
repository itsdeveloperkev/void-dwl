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

# Setup additional repositories if needed
setup_repos() {
  # Check if nonfree repo is needed (for proprietary drivers, Chrome, etc.)
  if lspci | grep -i nvidia >/dev/null 2>&1; then
    echo "NVIDIA GPU detected, adding nonfree repository..."
    install_pkg void-repo-nonfree
    install_pkg nvidia
  else
    # Still add nonfree for Chrome, etc.
    install_pkg void-repo-nonfree
  fi

  # Add multilib if on x86_64
  if [ "$(uname -m)" = "x86_64" ]; then
    echo "Adding multilib repository for 64-bit system..."
    install_pkg void-repo-multilib
  fi

  # Sync repositories
  $SUDO xbps-install -S
}

# Function to build dwl from source if desired
build_dwl() {
  echo "Building dwl from source..."
  cd /tmp
  git clone https://github.com/djpohly/dwl.git
  cd dwl
  
  # Copy custom config if it exists in our repo
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
  
  # Script to get dwl tags for waybar
  cat > ~/.local/bin/dwl-tags.sh << 'EOF'
#!/bin/sh
# Get dwl tags for waybar
# Requires: jq

get_dwl_tags() {
  # This is a placeholder - you would need a more complex implementation
  # to actually communicate with dwl
  echo '[{"name":"1","state":"focused"},{"name":"2","state":"inactive"}]'
}

get_dwl_tags
EOF
  chmod +x ~/.local/bin/dwl-tags.sh
}

# Function to copy and adapt configs
setup_configs() {
  echo "Setting up configuration files..."
  
  # Create necessary config directories
  mkdir -p ~/.config/waybar
  mkdir -p ~/.config/wofi
  mkdir -p ~/.config/alacritty
  mkdir -p ~/.config/dwl
  
  # Copy and adapt waybar config if it exists
  if [ -d ~/void-dwl-setup/configs/waybar ]; then
    # Adapt Sway-specific modules for dwl
    if [ -f ~/void-dwl-setup/configs/waybar/config ]; then
      sed -e 's/"sway\/workspaces"/{"custom\/dwl-tags"}/' \
          -e 's/"sway\/mode"//' \
          ~/void-dwl-setup/configs/waybar/config > ~/.config/waybar/config
      
      # Add custom module for dwl tags if not already present
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
    
    # Copy waybar style
    cp -r ~/void-dwl-setup/configs/waybar/style.css ~/.config/waybar/ 2>/dev/null || true
  fi
  
  # Copy other configs that don't need modification
  if [ -d ~/void-dwl-setup/configs/wofi ]; then
    cp -r ~/void-dwl-setup/configs/wofi/* ~/.config/wofi/ 2>/dev/null || true
  fi
  
  if [ -d ~/void-dwl-setup/configs/alacritty ]; then
    cp -r ~/void-dwl-setup/configs/alacritty/* ~/.config/alacritty/ 2>/dev/null || true
  fi
  
  # Setup greetd to use dwl instead of sway
  if [ -d ~/void-dwl-setup/configs/greetd ]; then
    if [ -f ~/void-dwl-setup/configs/greetd/config.toml ]; then
      # Replace sway with dwl in the greetd config
      sed 's/command = ".*sway.*"/command = "tuigreet --cmd dwl"/' \
          ~/void-dwl-setup/configs/greetd/config.toml > /tmp/config.toml
      $SUDO mv /tmp/config.toml /etc/greetd/config.toml
      $SUDO chmod 644 /etc/greetd/config.toml
    else
      # Create new greetd config
      cat > /tmp/config.toml << EOF
[terminal]
vt = 1

[default_session]
command = "tuigreet --cmd dwl"
user = "greeter"
EOF
      $SUDO mv /tmp/config.toml /etc/greetd/config.toml
      $SUDO chmod 644 /etc/greetd/config.toml
    fi
  fi
  
  # Set up environment variables for Wayland/dwl
  if [ ! -f ~/.bash_profile ] || ! grep -q "XDG_CURRENT_DESKTOP=dwl" ~/.bash_profile; then
    cat >> ~/.bash_profile << 'EOF'

# Wayland/dwl environment variables
export XDG_CURRENT_DESKTOP=dwl
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM=wayland
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export GDK_BACKEND=wayland
EOF
  fi
  
  if [ ! -f ~/.zprofile ] || ! grep -q "XDG_CURRENT_DESKTOP=dwl" ~/.zprofile; then
    cat >> ~/.zprofile << 'EOF'

# Wayland/dwl environment variables
export XDG_CURRENT_DESKTOP=dwl
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM=wayland
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export GDK_BACKEND=wayland
EOF
  fi
}

# Begin main script
echo "=== Starting Void Linux + dwl Installation ==="
check_void

# Get username
USERNAME=$(whoami)

# Setup repositories
echo "=== Setting up repositories ==="
setup_repos

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

echo "=== Installing dwl Dependencies ==="
for pkg in libX11-devel libXft-devel libXinerama-devel wayland-protocols wayland-devel wlroots-devel freetype-devel; do
  install_pkg "$pkg"
done

echo "=== Installing Window System ==="
# First try to install from repos
if xbps-query -Rs dwl >/dev/null 2>&1; then
  install_pkg dwl
else
  # If not in repos, try to build from source
  install_pkg git
  install_pkg base-devel
  build_dwl
fi

for pkg in greetd tuigreet waybar wofi wl-clipboard mako swaylock swayidle; do
  install_pkg "$pkg"
done

# Install dwl-specific scripts
install_dwl_scripts

# Enable greetd
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
# For Google Chrome specifically
if xbps-query -S void-repo-nonfree >/dev/null 2>&1; then
  if [ ! -e "/usr/bin/google-chrome" ]; then
    echo "Installing Google Chrome..."
    install_pkg google-chrome
  else
    echo "Google Chrome already installed, skipping."
  fi
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

# Copy and adapt configs from existing repository
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
  doas reboot

EOF
