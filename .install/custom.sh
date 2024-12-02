#!/bin/bash

# Función para instalar dependencias de SDDM
instalar_dependencias_sddm() {
    local paquetes=(
        "sddm"
        "qt5-graphicaleffects"
        "qt5-quickcontrols2"
        "qt5-svg"
        "qt5-base"
        "qt5-declarative"
        "qt5-tools"
        "qt5-wayland"
        "qt5-x11extras"
    )

    # Instalar paquetes necesarios para SDDM
    sudo pacman -S --noconfirm --needed "${paquetes[@]}" || {
        echo "Error: No se pudieron instalar las dependencias de SDDM"
        exit 1
    }
}

# Función para descargar e instalar tema Amy SDDM
instalar_tema_amy_sddm() {
    local temp_dir="$HOME/Downloads/Amy-SDDM"
    local theme_name="Amy-SDDM"
    local theme_dest="/usr/share/sddm/themes/$theme_name"
    local repo_url="https://github.com/L4ki/Amy-Plasma-Themes.git"

    # Limpiar instalaciones previas
    rm -rf "$temp_dir" "$theme_dest"

    # Clonar repositorio
    git clone --depth=1 "$repo_url" "$temp_dir" || {
        echo "Error: No se pudo descargar el tema SDDM"
        exit 1
    }

    # Instalar tema
    sudo mkdir -p "$theme_dest"
    sudo cp -r "$temp_dir/Amy SDDM Themes/Amy-SDDM/"* "$theme_dest/" || {
        echo "Error: No se pudo copiar los archivos del tema"
        exit 1
    }

    # Configurar permisos
    sudo chown -R root:root "$theme_dest"
    sudo chmod -R 755 "$theme_dest"
}

# Función para configurar SDDM
configurar_sddm() {
    # Crear directorio de configuración
    sudo mkdir -p /etc/sddm.conf.d

    # Configuración principal de SDDM
    local sddm_conf="/etc/sddm.conf.d/bspwm.conf"
    echo "[Theme]
Current=Amy-SDDM
ThemeDir=/usr/share/sddm/themes

[General]
Numlock=on
DisplayServer=x11
ServerPath=/usr/bin/X
ServerArguments=-nolisten tcp -dpi 96

[Users]
MaximumUid=60000
MinimumUid=1000" | sudo tee "$sddm_conf" > /dev/null

    # Habilitar servicio SDDM
    sudo systemctl enable sddm.service
}

# Función principal de personalización
personalizar_sddm() {
    # Instalar dependencias
    instalar_dependencias_sddm

    # Instalar tema Amy
    instalar_tema_amy_sddm

    # Configurar SDDM
    configurar_sddm

    echo "Personalización de SDDM completada exitosamente"
}

# Ejecutar personalización
personalizar_sddm