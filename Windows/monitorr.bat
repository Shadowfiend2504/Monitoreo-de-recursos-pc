@echo off
:loop
setlocal enabledelayedexpansion

set ARCHIVO_SALIDA=reporte_recursos.txt

echo ======================== > %ARCHIVO_SALIDA%
echo Escaneando recursos del sistema... >> %ARCHIVO_SALIDA%
echo ======================== >> %ARCHIVO_SALIDA%

:: 1. Uso del CPU
echo. >> %ARCHIVO_SALIDA%
for /f "tokens=2 delims==" %%C in ('wmic cpu get loadpercentage /value') do (
    set CPU=%%C
)
echo Uso del CPU: %CPU%%% >> %ARCHIVO_SALIDA%

:: 2. Uso de la memoria RAM
echo. >> %ARCHIVO_SALIDA%
for /f "tokens=2 delims==" %%A in ('wmic os get FreePhysicalMemory^ /value') do (
	set FreeMem=%%A
)
for /f "tokens=2 delims==" %%B in ('wmic os get TotalVisibleMemorySize /value') do (
	set TotalMem=%%B
)
set /a UsedMem=100 - (100 * FreeMem / TotalMem)
echo Uso de la memoria RAM: %UsedMem%%% >> %ARCHIVO_SALIDA%

:: 3. Espacio de los discos
echo. >> %ARCHIVO_SALIDA%
echo Uso de los discos: >> %ARCHIVO_SALIDA%
for /f "skip=1 tokens=1 delims=," %%A in ('wmic logicaldisk get FreeSpace^,Size /format:csv') do (
    set Drive=%%A
)
for /f "skip=1 tokens=3 delims=," %%C in ('wmic logicaldisk get FreeSpace^,Size /format:csv') do (
    set Size=%%C
)
echo Tamaño del disco: %Size% >> %ARCHIVO_SALIDA%
for /f "skip=1 tokens=2 delims=," %%B in ('wmic logicaldisk get FreeSpace^,Size /format:csv') do (
    set FreeSpace=%%B
)
echo Espacio libre en el disco: %FreeSpace% >> %ARCHIVO_SALIDA%

:: Usamos PowerShell para calcular el espacio usado y el porcentaje de uso
for /f %%P in ('powershell -command "([math]::Round(((%Size% - %FreeSpace%) / %Size%) * 100, 2))"') do (
    set Porcentaje=%%P
)

echo Disco !Drive!: !Porcentaje!%% de uso >> %ARCHIVO_SALIDA%

:: 4. Uso de la GPU (para sistemas con NVIDIA)
echo. >> %ARCHIVO_SALIDA%
echo Uso de la GPU: >> %ARCHIVO_SALIDA%
where nvidia-smi > nul 2>nul
if "!errorlevel!" equ "0" (
    echo Información de la GPU NVIDIA: >> %ARCHIVO_SALIDA%
    nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.free --format=csv,noheader >> %ARCHIVO_SALIDA%
	for /f "delims=" %%A in ('nvidia-smi --query-gpu=utilization.gpu --format=csv') do (
        	set gpu_utilization=%%A
    	)
) else (
    echo No se detectó una GPU NVIDIA. Intentando con wmic... >> %ARCHIVO_SALIDA%
    wmic path win32_videocontroller get caption,loadpercentage >> %ARCHIVO_SALIDA%
	set gpu_utilization=0
)

echo. >> %ARCHIVO_SALIDA%
echo == INFORMACIÓN DE PROCESOS Y MEMORIA == >> %ARCHIVO_SALIDA%
tasklist >> %ARCHIVO_SALIDA%


echo. >> %ARCHIVO_SALIDA%
echo ======================== >> %ARCHIVO_SALIDA%
echo Escaneo completado. >> %ARCHIVO_SALIDA%
echo ======================== >> %ARCHIVO_SALIDA%
echo La información se ha guardado en %ARCHIVO_SALIDA%



set DesktopPath=%USERPROFILE%\Desktop


if "%CPU%" geq "90" (
	powershell -Command "$Shortcut = (New-Object -COM WScript.Shell).CreateShortcut('%DesktopPath%\Alerta.lnk'); $Shortcut.TargetPath = 'C:\Proyecto analisis\reporte_recursos.txt'; $Shortcut.IconLocation = 'C:\Proyecto analisis\alerta.ico'; $Shortcut.Save()"
	cscript "C:\Proyecto analisis\alerta.vbs"
	goto correo
)
if "%UsedMem%" geq "90" (
	powershell -Command "$Shortcut = (New-Object -COM WScript.Shell).CreateShortcut('%DesktopPath%\Alerta.lnk'); $Shortcut.TargetPath = 'C:\Proyecto analisis\reporte_recursos.txt'; $Shortcut.IconLocation = 'C:\Proyecto analisis\alerta.ico'; $Shortcut.Save()"
	cscript "C:\Proyecto analisis\alerta.vbs"
	goto correo
)
if "%Porcentaje%" geq "80" (
	powershell -Command "$Shortcut = (New-Object -COM WScript.Shell).CreateShortcut('%DesktopPath%\Alerta.lnk'); $Shortcut.TargetPath = 'C:\Proyecto analisis\reporte_recursos.txt'; $Shortcut.IconLocation = 'C:\Proyecto analisis\alerta.ico'; $Shortcut.Save()"
	cscript "C:\Proyecto analisis\alerta.vbs"
	goto correo
)
if "%gpu_utilization%" geq "80" (
	powershell -Command "$Shortcut = (New-Object -COM WScript.Shell).CreateShortcut('%DesktopPath%\Alerta.lnk); $Shortcut.TargetPath = 'C:\Proyecto analisis\reporte_recursos.txt'; $Shortcut.IconLocation = 'C:\Proyecto analisis\alerta.ico'; $Shortcut.Save()"
	cscript "C:\Proyecto analisis\alerta.vbs"´
	goto correo
)

timeout /t 600 /nobreak >nul

goto loop

EXIT /B
:correo
:: Configurar las credenciales de correo (Tu correo de envío)
set "emailto=Enviar correo electrónico a"
set "emailFrom=Correo electrónico de"
set "emailSubject=Analisis de recursos de %USERPROFILE%"
set "emailBody=Se adjunta el archivo de los procesos del computado con los porcentajes de uso de espacio en disco,CPU,RAM y GPU en caso de tenerla."
set "smtpServer=smtp.gmail.com"
set "smtpPort=587"
set "emailUser=CORREO QUE ENVIA"
set "emailPassword=---------"

:: PowerShell para enviar el correo
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
    "}"
goto loop

endlocal