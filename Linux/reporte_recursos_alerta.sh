#!/bin/bash

# Archivo donde se guarda el reporte
output_file="reporte_recursos_$(date +%Y%m%d%H%M%S).txt"

# Limites
CPU_LIMIT=80
RAM_LIMIT=80
DISK_LIMIT=80

# Función para obtener valores de uso
check_cpu() {
  top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}' | cut -d'.' -f1
}

check_ram() {
  free | grep Mem | awk '{printf("%.0f", $3/$2 * 100)}'
}

check_disk() {
  df --total | grep "total" | awk '{print $5}' | sed 's/%//'
}

# Obtener valores
cpu_usage=$(check_cpu)
ram_usage=$(check_ram)
disk_usage=$(check_disk)

# Generar reporte
echo "========================" > $output_file
echo "Escaneando recursos del sistema..." >> $output_file
echo "========================" >> $output_file

echo "Uso del CPU: $cpu_usage%" >> $output_file
echo "Uso de la memoria RAM: $ram_usage%" >> $output_file
echo "Uso del disco: $disk_usage%" >> $output_file

echo "Información de procesos:" >> $output_file
ps -eo pid,comm,%mem,%cpu --sort=-%mem | head -20 >> $output_file

echo "========================" >> $output_file
echo "Escaneo completado." >> $output_file
echo "========================" >> $output_file

# Verificar si los límites se exceden
if (( cpu_usage > CPU_LIMIT || ram_usage > RAM_LIMIT || disk_usage > DISK_LIMIT )); then
  echo "Se detectó un uso elevado de recursos. Enviando alerta por correo electrónico..."
  
  # Enviar correo
  mail_subject="Alerta: Uso elevado de recursos"
  mail_recipient="esparaelproyecto178@gmail.com"
  echo "Se ha detectado un uso elevado de recursos. Consulte el archivo adjunto." | mail -s "$mail_subject" -A $output_file $mail_recipient
else
  echo "Todos los recursos están dentro de los límites normales."
fi
