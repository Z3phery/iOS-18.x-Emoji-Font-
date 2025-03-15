#!/system/bin/sh

# Directorio del módulo (donde se encuentra el script)
MODPATH=${0%/*}

# Configuración de registro
LOGFILE="$MODPATH/service.log" # Log file
MAX_LOG_SIZE=$((5 * 1024 * 1024)) # 5 MB
MAX_LOG_FILES=3 # Keep up to 3 archived logs
MAX_LOG_AGE_DAYS=7 # Delete logs older than 7 days

# Nombres de los paquetes de aplicaciones de Facebook
FACEBOOK_APPS="com.facebook.orca com.facebook.katana com.facebook.lite com.facebook.mlite"

# Servicios de fuentes GMS
GMS_FONT_PROVIDER="com.google.android.gms/com.google.android.gms.fonts.provider.FontsProvider"
GMS_FONT_UPDATER="com.google.android.gms/com.google.android.gms.fonts.update.UpdateSchedulerService"

# Parches de limpieza
DATA_FONTS_DIR="/data/fonts"
GMS_FONTS_DIR="/data/data/com.google.android.gms/files/fonts/opentype"

# Asegúra que el directorio de registro exista
mkdir -p "$MODPATH"

# Función de registro con comentarios del usuario
log() {
    # Delete old log files
    find "$MODPATH" -name "$(basename "$LOGFILE")*" -type f -mtime +$MAX_LOG_AGE_DAYS -exec rm -f {} \;

    # Compruebe si el archivo de registro existe y es demasiado grande
    if [ -f "$LOGFILE" ] && [ $(stat -c%s "$LOGFILE") -gt $MAX_LOG_SIZE ]; then
        # Rotar registros
        for i in $(seq $MAX_LOG_FILES -1 1); do
            if [ -f "$LOGFILE.$i" ]; then
                mv "$LOGFILE.$i" "$LOGFILE.$((i+1))"
            fi
        done
        mv "$LOGFILE" "$LOGFILE.1"
    fi

    # Crear mensaje de registro
    local log_message="$(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "$log_message" >> "$LOGFILE"
    
    # Mostrar mensaje simplificado al usuario
    echo "[*] $(echo "$1" | sed 's/^[A-Z]*: //')"
}

# Función para comprobar si existe un paquete/servicio
service_exists() {
    pm list packages | grep -q "$1"
    return $?
}


# Encabezado del script de registro
log "================================================"
log "iOS Emoji 18.4 service.sh Script"
log "Marca: $(getprop ro.product.brand)"
log "Dispositivo: $(getprop ro.product.model)"
log "Version de Android: $(getprop ro.build.version.release)"
log "Versión de SDK= $(getprop ro.system.build.version.sdk)"
log "Arquitectura= $(getprop ro.product.cpu.abi)"
log "================================================"

# Espere hasta que el dispositivo haya terminado de iniciarse
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 5
done

# Espere hasta que el directorio /sdcard esté disponible
while [ ! -d /sdcard ]; do
    sleep 5
done

log "INFO: Service started."

# Reemplazar las fuentes de emojis en la aplicación
replace_emoji_fonts() {
    log "INFO: Iniciando el proceso de reemplazo de emojis..."

    # Comprueba si existe la fuente emoji de origen
    if [ ! -f "$MODPATH/system/fonts/NotoColorEmoji.ttf" ]; then
        log "ERROR: No se encontró la fuente del emoji original. Se omite el reemplazo.."
        return
    fi

    # Encuentra todos los archivos .ttf que contienen "Emoji" en sus nombres
    EMOJI_FONTS=$(find /data/data -iname "*emoji*.ttf" -print)

    if [ -z "$EMOJI_FONTS" ]; then
        log "INFO: No se encontraron fuentes de emoji para reemplazar. Omitiendo."
        return
    fi

    # Reemplace cada fuente de emoji con la fuente personalizada
    for font in $EMOJI_FONTS; do
        # Check if the target font file is writable
        if [ ! -w "$font" ]; then
            log "ERROR: El archivo de fuente no se puede escribir: $font"
            continue
        fi

        log "INFO: Reemplazo de la fuente emoji: $font"
        if ! cp "$MODPATH/system/fonts/NotoColorEmoji.ttf" "$font"; then
            log "ERROR: No se pudo reemplazar la fuente del emoji: $font"
        else
            log "INFO: Fuente emoji reemplazada exitosamente: $font"
        fi

        # Set permissions for the replaced file
        if ! chmod 644 "$font"; then
            log "ERROR: No se pudieron establecer los permisos para: $font"
        else
            log "INFO: Se establecieron correctamente los permisos para: $font"
        fi
    done

    log "INFO: Proceso de reemplazo de emoji completado."
}

replace_emoji_fonts

# Forzar la detención de las aplicaciones de Facebook después de realizar todos los reemplazos
log "INFO: Forzar la detención de aplicaciones..."
for app in $FACEBOOK_APPS; do
    if ! am force-stop "$app"; then
        log "ERROR: No se pudo forzar la detención de la aplicación: $app"
    else
        log "INFO: Aplicación detenida forzosamente con éxito: $app"
    fi
done

# Agregue un retraso para permitir que el sistema procese los cambios
sleep 2

# Deshabilitar los servicios de fuentes GMS si existen
if service_exists "$GMS_FONT_PROVIDER"; then
    log "INFO: Deshabilitar el proveedor de fuentes GMS: $GMS_FONT_PROVIDER"
    if ! pm disable "$GMS_FONT_PROVIDER"; then
        log "ERROR: No se pudo deshabilitar el proveedor de fuentes GMS: $GMS_FONT_PROVIDER"
    else
        log "INFO: Proveedor de fuentes GMS deshabilitado exitosamente: $GMS_FONT_PROVIDER"
    fi
else
    log "INFO: No se encontró el proveedor de fuentes GMS: $GMS_FONT_PROVIDER"
fi

if service_exists "$GMS_FONT_UPDATER"; then
    log "INFO: Deshabilitar el actualizador de fuentes GMS: $GMS_FONT_UPDATER"
    if ! pm disable "$GMS_FONT_UPDATER"; then
        log "ERROR: No se pudo deshabilitar el actualizador de fuentes GMS: $GMS_FONT_UPDATER"
    else
        log "INFO: Actualizador de fuentes GMS deshabilitado exitosamente: $GMS_FONT_UPDATER"
    fi
else
    log "INFO: No se encontró el actualizador de fuentes GMS: $GMS_FONT_UPDATER"
fi

# Limpiar archivos de fuentes sobrantes
log "INFO: Limpieza de archivos de fuentes sobrantes..."
if [ -d "$DATA_FONTS_DIR" ]; then
    if ! rm -rf "$DATA_FONTS_DIR"; then
        log "ERROR: No se pudo limpiar el directorio: $DATA_FONTS_DIR"
    else
        log "INFO: Directorio limpiado exitosamente: $DATA_FONTS_DIR"
    fi
else
    log "INFO: Directorio no encontrado: $DATA_FONTS_DIR"
fi

# Eliminación de archivos .ttf en el directorio opentype (aún se necesitan pruebas)
# if [ -d "$GMS_FONTS_DIR" ]; then
#     if ! rm -rf "$GMS_FONTS_DIR"/*ttf; then
#         log "ERROR: Failed to clean up ttf files in directory: $GMS_FONTS_DIR"
#     else
#         log "INFO: Successfully cleaned up ttf files in directory: $GMS_FONTS_DIR"
#     fi
# else
#     log "INFO: Directory not found: $GMS_FONTS_DIR"
# fi

log "INFO: Servicio completado."
log "================================================"
