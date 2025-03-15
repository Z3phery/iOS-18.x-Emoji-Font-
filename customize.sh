#!/system/bin/sh

# Detalles del script
AUTOMOUNT=true
SKIPMOUNT=false
PROPFILE=false
POSTFSDATA=false
LATESTARTSERVICE=true

ui_print "*******************************"
ui_print "*          iOS Emoji 18.4         *"
ui_print "*******************************"

# Definiciones
FONT_DIR="$MODPATH/system/fonts"
FONT_EMOJI="NotoColorEmoji.ttf"
SYSTEM_FONT_FILE="/system/fonts/NotoColorEmoji.ttf"


# Función para comprobar si un paquete está instalado
package_installed() {
    local package="$1"
    if pm list packages | grep -q "$package"; then
        return 0
    else
        return 1
    fi
}

# Función para establecer un nombre de aplicación fácil de usar para el nombre del paquete, de lo contrario, se recurre al nombre del paquete
display_name() {
    local package_name="$1"
    case "$package_name" in
        "com.facebook.orca") echo "Messenger" ;;
        "com.facebook.katana") echo "Facebook" ;;
        "com.facebook.lite") echo "Facebook Lite" ;;
        "com.facebook.mlite") echo "Messenger Lite" ;;
        "com.google.android.inputmethod.latin") echo "Gboard" ;;
        *) echo "$package_name" ;;  # Nombre del paquete predeterminado si no se encuentra
    esac
}

# Función para montar un archivo de fuente
mount_font() {
    local source="$1"
    local target="$2"
    
    if [ ! -f "$source" ]; then
        ui_print "- Source file $source does not exist"
        return 1
    fi
    
    local target_dir=$(dirname "$target")
    if [ ! -d "$target_dir" ]; then
        ui_print "- Target directory $target_dir does not exist"
        return 1
    fi 
    
    mkdir -p "$(dirname "$target")"
    
    if mount -o bind "$source" "$target"; then
        chmod 644 "$target"
    else
        return 1
    fi
}

# Función para reemplazar emojis para una aplicación específica
replace_emojis() {
    local app_name="$1"
    local app_dir="$2"
    local emoji_dir="$3"
    local target_filename="$4"
    local app_display_name=$(display_name "$app_name")
    
    if package_installed "$app_name"; then
        ui_print "- Detectado: $app_display_name"
        mount_font "$FONT_DIR/$FONT_EMOJI" "$app_dir/$emoji_dir/$target_filename"
        ui_print "- Emojis montados: $app_display_name"
    else
        ui_print "- No instalados: $app_display_name"
    fi
}

# Función para borrar el caché de la aplicación
clear_cache() {
    local app_name="$1"
    local app_display_name=$(display_name "$app_name")
	
    # Comprobar si la aplicación existe
    if ! package_installed "$app_name"; then
        ui_print "- Omitir: $app_display_name (not installed)"
        return 0
    fi
	
	ui_print "- Limpieza de caché: $app_display_name"
	
    for subpath in /cache /code_cache /app_webview /files/GCache; do
        target_dir="/data/data/${app_name}${subpath}"
        if [ -d "$target_dir" ]; then
            rm -rf "$target_dir"
        fi
    done

    # Detención forzada
    am force-stop "$app_name"
    ui_print "- Cache borrada: $app_display_name"
}

# Extraer archivos del módulo
unzip -o "$ZIPFILE" 'system/*' -d "$MODPATH" >&2 || {
    ui_print "- No se pudieron extraer los archivos del módulo"
    exit 1
}

# Reemplazar las fuentes emoji del sistema
ui_print "- Instalando Emojis"
variants="SamsungColorEmoji.ttf LGNotoColorEmoji.ttf HTC_ColorEmoji.ttf AndroidEmoji-htc.ttf ColorUniEmoji.ttf DcmColorEmoji.ttf CombinedColorEmoji.ttf NotoColorEmojiLegacy.ttf"

for font in $variants; do
    if [ -f "/system/fonts/$font" ]; then
        if cp "$FONT_DIR/$FONT_EMOJI" "$FONT_DIR/$font"; then
            ui_print "- Reemplazado $font"
        else
            ui_print "- Error al reemplazar $font"
        fi
    fi
done
  
# Montar imagen emoji font en system
if [ -f "$FONT_DIR/$FONT_EMOJI" ]; then
    if mount_font "$FONT_DIR/$FONT_EMOJI" "$SYSTEM_FONT_FILE"; then
        ui_print "- System font montada con exito"
    else
        ui_print "- Error al montar system font"
    fi
else
    ui_print "- Fuente emoji font no encontrada. Pasando a montar system font ."
fi

# Reemplazar emojis de Facebook y Messenger
replace_emojis "com.facebook.orca" "/data/data/com.facebook.orca" "app_ras_blobs" "FacebookEmoji.ttf"
clear_cache "com.facebook.orca"
replace_emojis "com.facebook.katana" "/data/data/com.facebook.katana" "app_ras_blobs" "FacebookEmoji.ttf"
clear_cache "com.facebook.katana"

# Reemplazar los emojis de la aplicación Facebook Lite
replace_emojis "com.facebook.lite" "/data/data/com.facebook.lite" "files" "emoji_font.ttf"
clear_cache "com.facebook.lite"
replace_emojis "com.facebook.mlite" "/data/data/com.facebook.mlite" "files" "emoji_font.ttf"
clear_cache "com.facebook.mlite"
  
# Borrar la caché de Gboard si está instalado
ui_print "- Borrando cache de Gboard"
clear_cache "com.google.android.inputmethod.latin"
  
# Eliminar el directorio /data/fonts para Android 12+ en lugar de reemplazar los archivos
if [ -d "/data/fonts" ]; then
    rm -rf "/data/fonts"
    ui_print "- Se eliminó el directorio /data/fonts existente"
fi

# Manejar enlaces simbólicos fonts.xml
[[ -d /sbin/.core/mirror ]] && MIRRORPATH=/sbin/.core/mirror || unset MIRRORPATH
FONTS=/system/etc/fonts.xml
FONTFILES=$(sed -ne '/<family lang="und-Zsye".*>/,/<\/family>/ {s/.*<font weight="400" style="normal">\(.*\)<\/font>.*/\1/p;}' "$MIRRORPATH$FONTS")
for font in $FONTFILES; do
    ln -s /system/fonts/NotoColorEmoji.ttf "$MODPATH/system/fonts/$font"
done

# Establecer permisos
ui_print "- Estableciendo permisos"
set_perm_recursive "$MODPATH" 0 0 0755 0644
ui_print "- Espere ⏳"
ui_print "- iOS 18.4 emojis se han instalado con éxito"
ui_print "- Reinicia tu dispositivo para aplicar los cambios.  🔄"
ui_print "- Listo ✅"

# Soporte de OverlayFS basado en https://github.com/HuskyDG/magic_overlayfs 
OVERLAY_IMAGE_EXTRA=0
OVERLAY_IMAGE_SHRINK=true

# Utilice OverlayFS solo si está instalado Magisk_OverlayFS (dependencia) 
if [ -f "/data/adb/modules/magisk_overlayfs/util_functions.sh" ] && \
    /data/adb/modules/magisk_overlayfs/overlayfs_system --test; then
  ui_print "- Add support for overlayfs"
  . /data/adb/modules/magisk_overlayfs/util_functions.sh
  support_overlayfs && rm -rf "$MODPATH"/system
fi
