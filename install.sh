#!/bin/bash

# Función para imprimir mensajes de error
log_error() {
    echo -e "\e[31m[ERROR]\e[0m $1" >&2
}

# Función para imprimir mensajes de éxito
log_success() {
    echo -e "\e[32m[SUCCESS]\e[0m $1"
}

# Función para instalar dependencias básicas
instalar_dependencias() {
    # Actualizar paquetes
    sudo pacman -Syu --noconfirm

    # Instalar herramientas básicas
    local paquetes_base=(
        "base-devel"
        "git"
        "wget"
        "curl"
        "unzip"
        "mega-cmd"  # Reemplaza megadl
        "systemd"
    )

    sudo pacman -S --noconfirm --needed "${paquetes_base[@]}"
}

# Función para instalar AUR helper
instalar_aur_helper() {
    if ! command -v yay &> /dev/null; then
        log_success "Instalando yay (AUR helper)"
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
        cd ..
        rm -rf yay
    fi
}

# Función para crear directorios de configuración
crear_directorios_config() {
    local user_config_dir="$HOME/.config"
    local dirs_a_crear=(
        "$user_config_dir/bspwm"
        "$user_config_dir/sxhkd"
        "$user_config_dir/polybar"
        "$user_config_dir/picom"
        "$user_config_dir/alacritty"
        "$user_config_dir/rofi"
    )

    for dir in "${dirs_a_crear[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log_success "Creado directorio: $dir"
        fi
    done
}

# Función para manejar servicios de display manager
configurar_display_manager() {
    # Deshabilitar servicios de login existentes
    local servicios_a_deshabilitar=(
        "gdm.service"
        "lightdm.service"
        "lxdm.service"
        "mdm.service"
        "login.service"
    )

    for servicio in "${servicios_a_deshabilitar[@]}"; do
        if systemctl list-unit-files | grep -q "$servicio"; then
            sudo systemctl disable "$servicio" || log_error "No se pudo deshabilitar $servicio"
        fi
    done

    # Instalar SDDM
    sudo pacman -S sddm --noconfirm

    # Habilitar SDDM
    sudo systemctl enable sddm.service
    sudo systemctl start sddm.service
}

# Función principal de instalación
function necesarios() {
    # Instalar dependencias
    instalar_dependencias

    # Instalar AUR helper
    instalar_aur_helper

    # Instalar paquetes AUR
    yay -S --noconfirm \
        brave-bin \
        spotify \
        betterlockscreen

    # Crear directorios de configuración
    crear_directorios_config

    # Configurar display manager
    configurar_display_manager
}

function copia(){
  
  # Wallpaper
  
  mkdir ~/Wallpaper
  cp $ruta/dotfiles/Walpaper/tron_legacy1.jpg ~/Wallpaper/
  
  #polybar
  mkdir ~/.config/polybar
  cp -rv $ruta/dotfiles/polybar/* ~/.config/polybar/
  chmod +x ~/.config/polybar/launch.sh
  chmod +x ~/.config/polybar/scripts/playerctl.sh
  chmod +x ~/.config/polybar/scripts/playerctl_label.sh

  # Picom
  mkdir ~/.config/picom
  cp -rv $ruta/dotfiles/picom/* ~/.config/picom


# alacritty
  mkdir -p ~/.config/alacritty
  cp -rv $ruta/dotfiles/alacritty/alacritty.yml ~/.config/alacritty/
  
  # zsh
  sudo usermod --shell /usr/bin/zsh $usermod
  sudo usermod --shell /usr/bin/zsh root
  cp -rv $ruta/dotfiles/.zshrc ~/
  sudo ln -sf ~/.zshrc /root/.zshrc


  #Powerlevel10k
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
  sudo git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /root/powerlevel10k
  cp -rv $ruta/dotfiles/.p10k.zsh ~/
  sudo cp -rv $ruta/dotfiles/.p10k-root.zsh /root/.p10k.zsh
  
  #Rofi
  mkdir ~/.config/rofi
  cp -rv $ruta/dotfiles/rofi/* ~/.config/rofi/  
  chmod +x ~/.config/rofi/powermenu/powermenu  

  #Plugin sudo 
  cd /usr/share 
  sudo mkdir zsh-sudo 
  sudo chown $USER:$USER zsh-sudo/
  cd zsh-sudo
  wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/plugins/sudo/sudo.plugin.zsh

  #Betterlockscreen
  betterlockscreen -u ~/Wallpaper/tron_legacy1.jpg blur

  # SDDM
  # Deshabilitar el display manager actual de manera segura
  current_dm=$(sudo loginctl show-session $XDG_SESSION_ID 2>/dev/null | awk -F= '/Service/ {print $2}' || echo "")
  if [ -n "$current_dm" ]; then
    sudo systemctl disable "$current_dm"
    log_info "Disabled current display manager: $current_dm"
  fi

  # Habilitar SDDM
  sudo systemctl enable sddm
  log_success "SDDM enabled successfully"

  #Descargando fuentes necesarias
  cd /usr/share/fonts/
  sudo megadl --print-names 'https://mega.nz/file/GxFVSLLY#etuNc6QRrEl6wgl_ZatvomojDhkBTFPqlKS7ELk7KAM'
  sudo unzip fonts.zip
  sudo rm -rf fonts.zip

  #Bspwm & Sxhkd
  mkdir ~/.config/bspwm/
  mkdir ~/.config/sxhkd/
  cp -rv $ruta/dotfiles/bspwm/* ~/.config/bspwm/
  cp -rv $ruta/dotfiles/sxhkd/* ~/.config/sxhkd/
  cd ~/.config/bspwm/
  chmod +x bspwmrc
  cd scripts
  chmod +x bspwm_resize
 
}

function finalizar(){
  echo "A terminado la instalación"
  notify-send "Instalación finalizada"
  sleep 1
  notify-send "3"
  sleep 1
  notify-send "2"
  sleep 1
  notify-send "1"
  sleep 1
  notify-send "Reboot.."
  sleep 1
  reboot
}

if [ $(whoami) != 'root' ]; then
    ruta=$(pwd)
    necesarios
    #paquetes
    copia "$ruta"
    #betterlockscreen "$ruta"
    finalizar
else
    echo 'Error, el script no debe ser ejecutado como root.'
    exit 0
fi
