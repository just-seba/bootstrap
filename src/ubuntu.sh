#!/usr/bin/env bash
set -euo pipefail

################################################################
# functions
################################################################
echo_packet() { echo "📦️ $@ ..." ; }
echo_done() { echo "✅️ Done"; }
exists() {
  command -v $1 > /dev/null
}

apt_update() {
  sudo apt update || echo "⚠️: update exited with $?"
}

apt_install_q() { sudo apt-get install --no-install-recommends --assume-yes  $@; }

apt_install() {
  echo_packet $@
  apt_install_q $@
  echo_done
}

snap_install() {
  echo_packet $1
  sudo snap install $@
  echo_done
}

flatpak_install() {
  echo_packet $1
  if ! exists flatpak; then
    apt_install_q flatpak
  fi
  sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  flatpak install --or-update --assumeyes flathub $1
  echo_done
}

configure_gnome() {
  echo "⚙️ Configure GNOME"  
  echo "- Disable Ubuntu Dock"
  gnome-extensions disable ubuntu-dock@ubuntu.com
  echo "- Disable Desktop Icons"
  gnome-extensions disable ding@rastersoft.com
  echo "- Enable Enhanced Tiling"
  gnome-extensions enable tiling-assistant@ubuntu.com
  echo "- Enable App Indicators"
  gnome-extensions enable ubuntu-appindicators@ubuntu.com
  if ! dpkg --list vanilla-gnome-default-settings > /dev/null; then
    echo "- Install vanilla GNOME"
    apt_install gnome-session vanilla-gnome-default-settings
    read -p "Press ENTER to log out. Select GNOME on login"
    gnome-session-quit
    read -p "Waiting for log out ... Press ENTER to cancel"
  fi
  echo_done
}

install_smile() {
  echo "😀 Smile"
  echo "- Install Smile"
  flatpak_install it.mijorus.smile  
  echo "- Install and enable Smile GNOME extension"  
  if ! gnome-extensions list | grep 'smile-extension@mijorus.it' > /dev/null; then
    flatpak_install com.mattjakeman.ExtensionManager
    echo "Use the Extension Manager to install the Smile Extension"
    flatpak run com.mattjakeman.ExtensionManager    
  fi
  gnome-extensions enable smile-extension@mijorus.it
  echo "- Disable default emoji panel hotkey"
  gsettings set org.freedesktop.ibus.panel.emoji hotkey "[]"
  if ! dconf dump /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ | grep 'it.mijorus.smile' > /dev/null; then
    echo "⚠️ Custom keybinding missing. Add 'flatpak run it.mijorus.smile' as custom shortcut."
  fi
  echo_done
}

install_git() {
  echo_packet git

  # Install git
  apt_install_q git
  
  # Configure git
  git config --global core.editor nano
  git config --global pull.rebase true
  git config --global diff.algorithm histogram
  git config --global merge.conflictstyle diff3
  
  if ! git config --global --get user.name > /dev/null; then
    read -p "Git user name: " git_user_name
    git config --global user.name "$git_user_name"
  fi

  if ! git config --global --get user.email > /dev/null; then
    read -p "Git user email: " git_user_email
    git config --global user.email "$git_user_email"
  fi  

  # Install GCM
  git config --global credential.credentialStore secretservice
  if ! exists git-credential-manager; then
    apt_install_q dotnet-sdk-9.0
    dotnet tool install --global git-credential-manager
    export PATH="$PATH:/home/$(whoami)/.dotnet/tools"
    git-credential-manager configure
  fi

  echo_done
}

install_vscode() {
  snap_install code --classic
  # echo "⚙️ Configure VS Code"  
  # code --install-extension smcpeak.default-keys-windows  
  # Disable keybindings interfering with VS Code keybindings
  # gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-up "[]"
  # gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-down "[]"  
  # echo_done
}

configure_bash() {
  echo "⚙️ Configure bash"
  
  echo "🚀 Starship"
 if ! exists starship; then
    wget -qO- https://starship.rs/install.sh | sh
    starship preset no-nerd-font -o ~/.config/starship.toml
    grep --quiet "starship" ~/.bashrc || echo 'eval "$(starship init bash)"' >> ~/.bashrc
  fi

  echo "✏️ Custom font"
  # TODO: Install static ttf from GitHub Release or Rider can't set the font weight
  # see: https://askubuntu.com/questions/3697/how-do-i-install-fonts
  apt_install_q fonts-cascadia-code
  local CURRENT=$(gsettings get org.gnome.desktop.interface monospace-font-name)
  local TARGET="Cascadia Code PL Semi-Light 11"
  if [[ $CURRENT != *"$TARGET"* ]]; then
    gsettings set org.gnome.desktop.interface \
      monospace-font-name "$TARGET"
    # Reset: gsettings reset org.gnome.desktop.interface monospace-font-name
  fi

  echo_done
}

################################################################
# main
################################################################
apt_update
configure_gnome

echo "🥱️ Install every day desktop apps..."
install_smile
snap_install obsidian --classic
# flatpak_install com.bitwarden.desktop
# flatpak_install org.mozilla.firefox
# flatpak_install org.mozilla.Thunderbird
# flatpak_install org.libreoffice.LibreOffice

echo "🤓️ Install developer apps..."
# Common
# install_git
# install_vscode
apt_install htop
configure_bash
