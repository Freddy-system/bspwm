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
    # Create SDDM configuration directory
    sudo mkdir -p /etc/sddm.conf.d

    # Main SDDM configuration
    local sddm_conf="/etc/sddm.conf.d/bspwm.conf"
    echo "[Theme]
Current=Amy-SDDM
ThemeDir=/usr/share/sddm/themes

[General]
Numlock=on
InputMethod=fcitx
DisplayServer=wayland
WaylandDisplayServer=/usr/bin/Hyprland

[Users]
MaximumUid=60000
MinimumUid=1000
RememberLastUser=true
RememberLastSession=true
HideUsers=

[X11]
EnableHiDPI=true
ServerArguments=-nolisten tcp -dpi 192

[Wayland]
EnableHiDPI=true" | sudo tee "$sddm_conf" > /dev/null

    # Theme-specific configuration
    local theme_conf="/usr/share/sddm/themes/Amy-SDDM/theme.conf"
    echo "[General]
background=Background.jpg
type=image
color=#1a1b26
fontSize=12
fontFamily=JetBrains Mono Nerd Font
loginButtonText=Login
loginButtonIcon=system-shutdown
loginButtonIconSize=48

# Visual Effects
blur=true
recursiveBlurLoops=5
recursiveBlurRadius=15
recursiveBlurType=gaussian
backgroundBlur=true
backgroundBlurRadius=50

# Color Scheme (Tokyo Night inspired)
primaryColor=#7aa2f7
secondaryColor=#bb9af7
accentColor=#9ece6a
textColor=#c0caf5
backgroundColor=#1a1b26
shadowColor=#414868

# Layout Customization
[Layout]
clockVisible=true
clockFormat=%I:%M %p
dateVisible=true
dateFormat=%A, %B %d
showLoginButton=true
loginButtonPosition=center

# User Card Styling
[UserCard]
showFullName=true
nameTextColor=#c0caf5
avatarSize=128
avatarBorderWidth=3
avatarBorderColor=#7aa2f7

# Power Options
[PowerOptions]
showSuspend=true
showRestart=true
showShutdown=true
powerIconSize=32
powerButtonStyle=round

# Translations and Text
[Translations]
welcome=Welcome to BSPWM
welcomeStyle=elegant
loginButtonTooltip=Login to your session
suspendTooltip=Suspend the system
restartTooltip=Restart the system
shutdownTooltip=Shutdown the system" | sudo tee "$theme_conf" > /dev/null

    log_success "SDDM configuration completed with enhanced visual styling"
}

set_default_wallpaper() {
    local wallpaper_src=".install/wallpapers/default.jpg"
    local wallpaper_dest="/usr/share/sddm/themes/Amy-SDDM/Background.jpg"

    if [[ -f "$wallpaper_src" ]]; then
        sudo cp "$wallpaper_src" "$wallpaper_dest"
        log_success "Custom wallpaper set for SDDM"
    else
        log_warning "No default wallpaper found"
    fi
}

# ------------------------------------------------------
# Display Manager Configuration
# ------------------------------------------------------
configure_display_manager() {
    # Detect and disable current display manager
    local current_dm=""
    
    # Try multiple methods to detect current display manager
    if [ -L /etc/systemd/system/display-manager.service ]; then
        current_dm=$(basename "$(readlink /etc/systemd/system/display-manager.service)" .service)
    elif command -v loginctl &> /dev/null; then
        current_dm=$(loginctl show-session "$XDG_SESSION_ID" 2>/dev/null | awk -F= '/Service/ {print $2}' | cut -d. -f1)
    fi

    # Disable current display manager if found
    if [[ -n "$current_dm" && "$current_dm" != "sddm" ]]; then
        log_warning "Detected current display manager: $current_dm"
        sudo systemctl disable "$current_dm.service" || true
        log_success "Disabled $current_dm display manager"
    fi

    # Enable SDDM
    sudo systemctl enable sddm.service || {
        log_error "Failed to enable SDDM"
        exit 1
    }

    log_success "Display manager configured successfully"
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
        set_default_wallpaper
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
