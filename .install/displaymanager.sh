#!/bin/bash

# ------------------------------------------------------
# Display Manager Installation Script for BSPWM
# ------------------------------------------------------

# Strict mode for better error handling
set -euo pipefail

# ------------------------------------------------------
# Colors and Formatting
# ------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ------------------------------------------------------
# Logging and Output Functions
# ------------------------------------------------------
log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# ------------------------------------------------------
# Compatibility Checks
# ------------------------------------------------------
check_system_compatibility() {
    # Check Linux distribution
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" != "arch" ]] && [[ "$ID_LIKE" != *"arch"* ]]; then
            log_error "This script is designed for Arch Linux or Arch-based distributions"
            exit 1
        fi
    else
        log_error "Unable to determine Linux distribution"
        exit 1
    fi

    # Check system architecture
    local arch=$(uname -m)
    if [[ "$arch" != "x86_64" ]]; then
        log_error "This script supports only x86_64 architecture"
        exit 1
    fi

    # Check minimum kernel version
    local kernel_version=$(uname -r | cut -d. -f1-2)
    local min_kernel="5.10"
    if [[ "$(printf '%s\n' "$min_kernel" "$kernel_version" | sort -V | head -n1)" != "$min_kernel" ]]; then
        log_error "Minimum kernel version $min_kernel required"
        exit 1
    fi
}

# ------------------------------------------------------
# Dependency Checks
# ------------------------------------------------------
check_dependencies() {
    local dependencies=(
        "git"
        "wget"
        "gum"
        "systemctl"
        "qt5-graphicaleffects"
        "qt5-quickcontrols2"
        "qt5-svg"
        "qt5-base"
    )
    local missing_deps=()

    for dep in "${dependencies[@]}"; do
        if ! pacman -Qi "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_warning "Missing dependencies: ${missing_deps[*]}"
        sudo pacman -S --noconfirm "${missing_deps[@]}" || {
            log_error "Failed to install dependencies"
            exit 1
        }
    fi

    # Additional checks for SDDM and theme compatibility
    if ! command -v sddm &> /dev/null; then
        log_warning "SDDM not installed. Will install during setup."
    fi
}

# ------------------------------------------------------
# Root Check
# ------------------------------------------------------
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script must NOT be run as root"
        exit 1
    fi
}

# ------------------------------------------------------
# SDDM Installation Functions
# ------------------------------------------------------
install_sddm_packages() {
    local sddm_packages=(
        "sddm"
        "qt5-graphicaleffects"
        "qt5-quickcontrols2"
        "qt5-svg"
        "qt5-base"
    )

    log_info "Installing SDDM and dependencies..."
    sudo pacman -S --noconfirm --needed "${sddm_packages[@]}" || {
        log_error "Failed to install SDDM packages"
        exit 1
    }
}

# ------------------------------------------------------
# Theme Installation Functions
# ------------------------------------------------------
validate_theme_download() {
    local theme_dir="$1"
    if [[ ! -d "$theme_dir" ]] || [[ -z "$(ls -A "$theme_dir")" ]]; then
        log_error "Theme download failed or theme directory is empty"
        exit 1
    }
}

install_amy_sddm_theme() {
    local temp_dir="$HOME/Downloads/Amy-SDDM"
    local theme_name="Amy-SDDM"
    local theme_dest="/usr/share/sddm/themes/$theme_name"
    local repo_url="https://github.com/L4ki/Amy-Plasma-Themes.git"

    # Clean previous installations
    rm -rf "$temp_dir" "$theme_dest"

    # Clone repository
    log_info "Downloading Amy SDDM Theme..."
    git clone --depth=1 "$repo_url" "$temp_dir" || {
        log_error "Failed to clone theme repository"
        exit 1
    }

    # Validate download
    validate_theme_download "$temp_dir/Amy SDDM Themes/Amy-SDDM"

    # Install theme
    sudo mkdir -p "$theme_dest"
    sudo cp -r "$temp_dir/Amy SDDM Themes/Amy-SDDM/"* "$theme_dest/" || {
        log_error "Failed to copy theme files"
        exit 1
    }

    # Set permissions
    sudo chown -R root:root "$theme_dest"
    sudo chmod -R 755 "$theme_dest"

    log_success "Amy SDDM Theme installed successfully"
}

# ------------------------------------------------------
# SDDM Configuration Functions
# ------------------------------------------------------
configure_sddm() {
    # Crear directorio de configuración
    sudo mkdir -p /etc/sddm.conf.d

    # Configuración principal de SDDM
    local sddm_conf="/etc/sddm.conf.d/bspwm.conf"
    echo "[Theme]
Current=Amy-SDDM
ThemeDir=/usr/share/sddm/themes

[General]
Numlock=on
InputMethod=
DisplayServer=x11
ServerPath=/usr/bin/X
ServerArguments=-nolisten tcp -dpi 96

[Users]
MaximumUid=60000
MinimumUid=1000
RememberLastUser=true
RememberLastSession=true

[X11]
EnableHiDPI=true
ServerArguments=-nolisten tcp" | sudo tee "$sddm_conf" > /dev/null

    # Configuración principal de SDDM
    local main_conf="/etc/sddm.conf"
    echo "[General]
Numlock=on
InputMethod=
DisplayServer=x11

[Theme]
Current=Amy-SDDM

[Users]
MaximumUid=60000
MinimumUid=1000
RememberLastUser=true
RememberLastSession=true" | sudo tee "$main_conf" > /dev/null

    # Tema específico
    local theme_conf="/usr/share/sddm/themes/Amy-SDDM/theme.conf"
    echo "[General]
background=Background.jpg
type=image
color=#1a1b26
fontSize=10
blur=true
recursiveBlurLoops=3
recursiveBlurRadius=10
font=JetBrains Mono Nerd Font

[Layout]
clockVisible=true
showLoginButton=true

[Translations]
welcome=Welcome to BSPWM" | sudo tee "$theme_conf" > /dev/null

    log_success "SDDM configuration completed"
}

configure_display_manager() {
    # Detener y deshabilitar display managers existentes
    local display_managers=(
        "gdm"
        "lightdm"
        "lxdm"
        "mdm"
    )

    for dm in "${display_managers[@]}"; do
        if systemctl is-active "$dm" &>/dev/null; then
            log_warning "Stopping $dm display manager"
            sudo systemctl stop "$dm.service" || true
        fi
        
        if systemctl is-enabled "$dm" &>/dev/null; then
            log_warning "Disabling $dm display manager"
            sudo systemctl disable "$dm.service" || true
        fi
    done

    # Configuración de SDDM
    sudo systemctl stop sddm.service 2>/dev/null || true
    sudo systemctl disable sddm.service 2>/dev/null || true
    
    # Recargar systemd
    sudo systemctl daemon-reload

    # Habilitar y iniciar SDDM
    sudo systemctl enable sddm.service || {
        log_error "Failed to enable SDDM service"
        return 1
    }

    sudo systemctl start sddm.service || {
        log_error "Failed to start SDDM service"
        return 1
    }

    log_success "Display manager configured successfully"
}

diagnose_display_manager() {
    log_info "Diagnosing SDDM and Display Manager configuration..."
    
    # Verificar estado de SDDM
    echo "SDDM Service Status:"
    systemctl status sddm.service || true

    # Verificar configuraciones
    echo -e "\nSDDM Configurations:"
    echo "Main Configuration:"
    cat /etc/sddm.conf 2>/dev/null || echo "No main configuration found"
    
    echo -e "\nTheme Configuration:"
    cat /etc/sddm.conf.d/bspwm.conf 2>/dev/null || echo "No theme configuration found"
    
    echo -e "\nAvailable Display Managers:"
    ls /usr/lib/systemd/system/*display-manager.service 2>/dev/null || echo "No display managers found"
}

# ------------------------------------------------------
# Main Installation Function
# ------------------------------------------------------
main() {
    check_root
    check_system_compatibility
    check_dependencies

    if gum confirm "Install SDDM with Amy Theme for BSPWM?"; then
        install_sddm_packages
        install_amy_sddm_theme
        configure_sddm
        configure_display_manager

        log_success "SDDM and Amy Theme installation completed!"
        
        if gum confirm "Reboot now to apply changes?"; then
            sudo reboot
        fi
    else
        log_warning "SDDM installation cancelled"
    fi
}

# Execute main function
main
