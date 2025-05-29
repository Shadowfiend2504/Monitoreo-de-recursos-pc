#!/bin/bash

# === CONFIGURACIÓN ===
ARCHIVO_SALIDA="$(dirname "$0")/reporte_recursos.txt"
LIMITE_CPU=90
LIMITE_RAM=90
LIMITE_DISCO=80
EMAIL="tucorreo@dominio.com"

# === INICIO DEL MONITOREO ===
while true; do
    echo "==== REPORTE DE RECURSOS ====" > "$ARCHIVO_SALIDA"
    echo "Fecha y hora: $(date)" >> "$ARCHIVO_SALIDA"

    # --- CPU ---
    CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print 100-$8}')
    echo "CPU: ${CPU}% usado" >> "$ARCHIVO_SALIDA"

    # --- RAM ---
    MEM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
    MEM_USO=$(free -m | awk '/Mem:/ {print $3}')
    MEM_PERC=$((100 * MEM_USO / MEM_TOTAL))
    echo "RAM usada: ${MEM_USO}MB (${MEM_PERC}%)" >> "$ARCHIVO_SALIDA"

    # --- DISCO ---
    echo -e "\n=== USO DE DISCO ===" >> "$ARCHIVO_SALIDA"
    MAX_DISCO=0
    while read -r line; do
        USO=$(echo $line | awk '{print $5}' | tr -d '%')
        PUNTO=$(echo $line | awk '{print $6}')
        echo "Disco $PUNTO: $USO% usado" >> "$ARCHIVO_SALIDA"
        [ "$USO" -gt "$MAX_DISCO" ] && MAX_DISCO=$USO
    done < <(df -h --output=source,pcent,target | grep -vE '^Filesystem' | awk '{print $2, $3}')

    # --- PROCESOS PRINCIPALES ---
    echo -e "\n=== PROCESOS PRINCIPALES ===" >> "$ARCHIVO_SALIDA"
    ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 10 >> "$ARCHIVO_SALIDA"

    # === CHEQUEO DE ALERTAS ===
    ALERTA=0
    MSG=""
    if (( $(echo "$CPU >= $LIMITE_CPU" | bc -l) )); then
        ALERTA=1
        MSG+="CPU alta: $CPU%\n"
    fi
    if (( MEM_PERC >= LIMITE_RAM )); then
        ALERTA=1
        MSG+="RAM alta: $MEM_PERC%\n"
    fi
    if (( MAX_DISCO >= LIMITE_DISCO )); then
        ALERTA=1
        MSG+="Disco lleno: $MAX_DISCO%\n"
    fi

    if [ "$ALERTA" -eq 1 ]; then
        echo -e "ALERTA DE RECURSOS:\n$MSG" | mail -s "Alerta de recursos en $(hostname)" -a "$ARCHIVO_SALIDA" "$EMAIL"
        # Espera más tiempo tras alerta para evitar spam
        sleep 300
    else
        sleep 60
    fi
done
