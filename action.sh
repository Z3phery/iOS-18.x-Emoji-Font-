#!/system/bin/sh
MODPATH="${0%/*}"

set +o standalone 2>/dev/null
unset ASH_STANDALONE 2>/dev/null

# Validar que exista el script requerido
SCRIPT="$MODPATH/service.sh"
if [ ! -f "$SCRIPT" ]; then
    echo -e "\nERROR: Missing service.sh" >&2
    exit 1
fi

# Ejecutar script con manejo de errores
if ! sh "$SCRIPT"; then
    echo -e "\nERROR: service.sh failed" >&2
    exit 1
fi

echo -e "\nOperation completed successfully!\n"

exit 0
