@echo off
setlocal enabledelayedexpansion

REM === CONFIGURACIÓN CENTRALIZADA ===
set "ARCHIVO_SALIDA=%~dp0reporte_recursos.txt"
set "ARCHIVO_LOG=%~dp0monitorr_error.log"
set "LIMITE_CPU=90"
set "LIMITE_RAM=90"
set "LIMITE_DISCO=80"
set "DesktopPath=%USERPROFILE%\Desktop"
set "PROCESOS=chrome.exe explorer.exe svchost.exe"
set "emailto=Enviar correo electrónico a"
set "emailFrom=Correo electrónico de"
set "emailSubject=Analisis de recursos de %USERPROFILE%"
set "emailBody=Se adjunta el archivo de los procesos del computado con los porcentajes de uso de espacio en disco,CPU,RAM y GPU en caso de tenerla."
set "smtpServer=smtp.gmail.com"
set "smtpPort=587"
set "emailUser=CORREO QUE ENVIA"
set "emailPassword=---------"

REM === LIMPIEZA DE ARCHIVOS ANTIGUOS ===
if exist "%ARCHIVO_SALIDA%" del "%ARCHIVO_SALIDA%"

REM === INICIO DEL MONITOREO ===
:loop
REM Inicializar variables para este ciclo
set "MaxDisco=0"

REM Limpiar archivo de salida
echo ==== REPORTE DE RECURSOS ==== > "%ARCHIVO_SALIDA%"
echo Fecha y hora: %date% %time% >> "%ARCHIVO_SALIDA%"

REM --- CPU ---
where wmic >nul 2>&1
if errorlevel 1 (
    echo [ERROR] wmic no encontrado >> "%ARCHIVO_LOG%"
    echo No se puede obtener el uso de CPU. >> "%ARCHIVO_SALIDA%"
    set "CPU=0"
) else (
    for /f "skip=1 tokens=2 delims== " %%A in ('wmic cpu get loadpercentage /value') do (
        if not "%%A"=="" set "CPU=%%A"
    )
    echo CPU: %CPU%%% >> "%ARCHIVO_SALIDA%"
)

REM --- RAM ---
for /f "skip=1 tokens=2 delims== " %%A in ('wmic OS get FreePhysicalMemory /value') do (
    if not "%%A"=="" set "FreeMem=%%A"
)
for /f "skip=1 tokens=2 delims== " %%A in ('wmic computersystem get TotalPhysicalMemory /value') do (
    if not "%%A"=="" set "TotalMem=%%A"
)
REM Convertir a MB y calcular porcentaje usado
set /a UsedMemMB=(TotalMem/1024-FreeMem/1024)
set /a UsedMemPerc=100-((FreeMem*100)/(TotalMem/1024))
echo RAM usada: !UsedMemMB! MB (!UsedMemPerc!%%) >> "%ARCHIVO_SALIDA%"

REM --- DISCO (todas las unidades) ---
echo. >> "%ARCHIVO_SALIDA%"
echo === USO DE DISCO === >> "%ARCHIVO_SALIDA%"
for /f "skip=1 tokens=1,2,3 delims=," %%A in ('wmic logicaldisk get DeviceID^,FreeSpace^,Size /format:csv') do (
    if not "%%A"=="" (
        set "Unidad=%%B"
        set "FreeSpace=%%C"
        set "Size=%%D"
        if defined Unidad if defined FreeSpace if defined Size (
            set /a UsedSpace=Size-FreeSpace
            set /a UsedPerc=(UsedSpace*100)/Size
            echo Disco !Unidad!: !UsedPerc!%% usado >> "%ARCHIVO_SALIDA%"
            REM Guardar el mayor porcentaje para alerta
            if !UsedPerc! gtr !MaxDisco! set MaxDisco=!UsedPerc!
        )
    )
)
if not defined MaxDisco set MaxDisco=0

REM --- PROCESOS PRINCIPALES ---
echo. >> "%ARCHIVO_SALIDA%"
echo === PROCESOS PRINCIPALES === >> "%ARCHIVO_SALIDA%"
tasklist /FI "STATUS eq running" | findstr /I "%PROCESOS%" >> "%ARCHIVO_SALIDA%"

REM === CHEQUEO DE ALERTAS ===
if %CPU% geq %LIMITE_CPU% goto alerta
if !UsedMemPerc! geq %LIMITE_RAM% goto alerta
if !MaxDisco! geq %LIMITE_DISCO% goto alerta

REM Esperar 60 segundos antes de repetir
timeout /t 60 >nul
goto loop

:alerta
REM --- CREAR ACCESO DIRECTO Y MOSTRAR ALERTA ---
if not exist "%DesktopPath%\Alerta.lnk" (
    powershell -Command "$s=(New-Object -COM WScript.Shell).CreateShortcut('%DesktopPath%\Alerta.lnk');$s.TargetPath='%ARCHIVO_SALIDA%';$s.IconLocation='%~dp0alerta.ico';$s.Save()" 2>>"%ARCHIVO_LOG%"
)
cscript "%~dp0alerta.vbs" 2>>"%ARCHIVO_LOG%"
goto correo

:correo
REM --- ENVÍO DE CORREO Y MANEJO DE ERRORES ---
powershell -NoProfile -Command ^
    "$emailFrom = '%emailFrom%';" ^
    "$emailTo = '%emailTo%';" ^
    "$subject = '%emailSubject%';" ^
    "$body = '%emailBody%';" ^
    "$smtpServer = '%smtpServer%';" ^
    "$smtpPort = '%smtpPort%';" ^
    "$username = '%emailUser%';" ^
    "$password = '%emailPassword%';" ^
    "$attachment = '%ARCHIVO_SALIDA%';" ^
    "try {" ^
        "$securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force;" ^
        "$credential = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $securePassword;" ^
        "Send-MailMessage -From $emailFrom -To $emailTo -Subject $subject -Body $body -SmtpServer $smtpServer -Port $smtpPort -Credential $credential -UseSsl -Attachments $attachment;" ^
        "Write-Host 'Correo enviado exitosamente.'" ^
    "} catch {" ^
        "Write-Host 'Error al enviar el correo:' $_.Exception.Message;" ^
        "Add-Content -Path '%ARCHIVO_LOG%' -Value ('[' + (Get-Date) + '] Error al enviar el correo: ' + $_.Exception.Message)" ^
    "}"
timeout /t 300 >nul
goto loop