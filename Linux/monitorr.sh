#!/bin/bash
echo "========================"
echo "Escaneando recursos del sistema..."
echo "========================"

echo "Uso del CPU:"
top -bn1 | grep "Cpu(s)"

echo "Uso de la memoria RAM:"
free -h

echo "Uso de los discos:"
df -h

echo "Información de procesos:"
ps -eo pid,comm,%mem,%cpu --sort=-%mem | head -20


echo "========================"
echo "Escaneo completado."
echo "========================"

read
