#------------------------------------------------------------
# APL1. Ejercicio4
# Materia: Virtualizacion de hardware
# Ingeniería en Informática
# Universidad Nacional de La Matanza (UNLaM)
# Año: 2025
#
# Integrantes del grupo:
# - De Luca, Leonel Maximiliano DNI: 42.588.356
# - La Giglia, Rodrigo Ariel DNI: 33334248
# - Marco, Nicolás Agustín DNI: 40885841
# - Marrone, Micaela Abril DNI: 45683584
#-------------------------------------------------------------

<#
.SYNOPSIS
    Script para monitorear un directorio, organizar archivos por extensión y crear backups automáticamente.

.DESCRIPTION
    Este script monitorea un directorio especificado. Cuando se agregan archivos nuevos, los organiza en subdirectorios
    por tipo de extensión. Cuando la cantidad de archivos procesados alcanza un límite, se genera un archivo ZIP como backup.
    Puede ejecutarse en segundo plano como demonio, y también puede ser detenido.

.PARAMETER directorio
    Ruta del directorio a monitorear. Obligatorio.

.PARAMETER salida
    Ruta donde se guardarán los backups. Obligatorio salvo cuando se usa -kill.

.PARAMETER cantidad
    Cantidad de archivos procesados antes de generar un backup.

.PARAMETER kill
    Finaliza el demonio que monitorea el directorio especificado.

.PARAMETER help
    Muestra este mensaje de ayuda.

.PARAMETER bg
    Uso interno. Indica que se debe iniciar en segundo plano.

.EXAMPLE
    .\Ejercicio.ps1 -directorio C:\MisFrutas -salida C:\Backups -cantidad 5

    Inicia el demonio que monitorea el directorio C:\MisFrutas. 
    Cada 5 archivos nuevos, se genera un backup en C:\Backups.

.EXAMPLE
    .\Ejercicio.ps1 -directorio C:\MisFrutas -kill
    
    Detiene el demonio que monitorea el directorio C:\MisFrutas.
    
    #>

    
    param (
        [Parameter(HelpMessage="Ruta del directorio a monitorear")]
        [ValidateScript({
            if (-not (Test-Path -Path $_ -PathType Container)) {
                Write-Host "El directorio especificado no existe: $_" -ForegroundColor Red
                exit
            }
            $true
        })] 
        [string][Alias("d")]$directorio,
        
        [Parameter(HelpMessage="Ruta donde se guardarán los backups.")] 
        
        [string][Alias("s")]$salida,
        
        [Parameter(HelpMessage="Matar el demonio del directorio")] 
        [switch][Alias("k")]$kill,
        
        [Parameter(HelpMessage="Cantidad de elementos hasta hacer backup")] 
        [int][Alias("c")]$cantidad,
        
        [Parameter(HelpMessage="Iniciar en segundo plano (interno)")] 
        [switch]$bg,
        
        [Parameter(HelpMessage="Muestra esta ayuda.")] 
        [switch][Alias("h")]$help
        )
        function CrearBackup {
            $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
            $base = Split-Path $directorio -Leaf
            $zip = "$base`_$ts.zip"  
            $dest = Join-Path $salida $zip
            Compress-Archive -Path (Join-Path $directorio '*') -DestinationPath $dest -Force
            $global:contador = 0
        }
        
        function ProcesarArchivo($file) {
            Start-Sleep -Milliseconds 300
            try {
                if (-not (Test-Path $file -PathType Leaf)) { return }
        
                $ext = [IO.Path]::GetExtension($file).TrimStart('.')
                if ([string]::IsNullOrEmpty($ext)) { $ext = 'SinExtension' }
        
                $dest = Join-Path $directorio $ext.ToUpper()
                if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }
        
                Move-Item -Path $file -Destination $dest -Force
                
                $global:contador++
                if ($global:contador -ge $cantidad) { CrearBackup }
            }
            catch {
                Write-Warning "Error al mover archivo: $_"
            }
        }
        
        if($help){
        Write-Host "Uso: .\Ejercicio.ps1 -directorio <ruta> [-salida <ruta>] [-kill] [-cantidad <n>] [-help]" -ForegroundColor Green
        Write-Host "-directorio: Ruta del directorio a monitorear." -ForegroundColor Green
        Write-Host "-salida: Ruta donde se guardarán los backups." -ForegroundColor Green
        Write-Host "-kill: Matar el demonio del directorio." -ForegroundColor Green
        Write-Host "-cantidad: Cantidad de elementos hasta hacer backup." -ForegroundColor Green
        Write-Host "-help: Muestra esta ayuda." -ForegroundColor Green
        exit
    }
    
    


if (-not $salida -and -not $kill) {
    Write-Host "Error: El parametro -salida es obligatorio." -ForegroundColor Red
    exit
}
if($salida){
    $salida = (Resolve-Path -Path $salida).Path
}

$directorio = (Resolve-Path -Path $directorio).Path

$pidBase = Join-Path $HOME ".frutasdemonio"
if (-not (Test-Path $pidBase)) {
    New-Item -ItemType Directory -Path $pidBase -Force | Out-Null
}

# Generar archivo PID único por hash del path absoluto
$hash = [System.BitConverter]::ToString(
    (New-Object System.Security.Cryptography.SHA256Managed).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($directorio))
) -replace '-', ''
$pidFile = Join-Path $pidBase "daemon_$hash.pid"

if($kill -and ($salida -or $cantidad)) {
    Write-Host "Error: no se puede usar -kill con -salida o -cantidad." -ForegroundColor Red
    exit 1
}

if ($kill) {
    if (Test-Path $pidFile) {
        $existingPID = Get-Content $pidFile -ErrorAction SilentlyContinue
        Stop-Process -Id $existingPID -Force -ErrorAction SilentlyContinue
        Remove-Item $pidFile -Force
        Write-Host "Demonio detenido para: $directorio" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "No hay demonio en ejecución para: $directorio" -ForegroundColor Yellow
        exit 1
    }
}

# Obtenemos el PID del proceso actual
$currentPID = $PID

if (Test-Path $pidFile) {
    $existingPID = Get-Content $pidFile -ErrorAction SilentlyContinue
    if ($existingPID) {
        $proc = Get-Process -Id $existingPID -ErrorAction SilentlyContinue
        if ($proc) {
            # Si el PID es distinto al proceso actual, hay otro demonio activo => error
            if ($existingPID -ne $currentPID) {
                Write-Host "Error: ya existe demonio (PID $existingPID) para: $directorio" -ForegroundColor Red
                exit 1
            }
            # Si es el mismo PID que este proceso, está todo ok, seguimos.
        } else {
            # Proceso muerto, eliminar archivo .pid
            Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
        }
    }
}

if (-not $salida -or -not $cantidad) {
    Write-Host "Error: falta -salida o -cantidad." -ForegroundColor Red
    exit 1
}
$directorio = (Resolve-Path -Path $directorio).Path


if (-not (Test-Path -Path $salida -PathType Container)) {
    Write-Host "Error: salida no existe: $salida" -ForegroundColor Red
    exit 1
}


$IsWindows = $PSVersionTable.PSEdition -eq 'Desktop' -or $env:OS -like '*Windows*'
if (-not $bg) {
    $argumentos = @('-File', "`"$PSCommandPath`"", '-d', "`"$directorio`"", '-s', "`"$salida`"", '-c', $cantidad, '-bg')

    if ($IsWindows) {
        $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList $argumentos -WindowStyle Hidden -PassThru
    } else {
        $proc = Start-Process -FilePath 'pwsh' -ArgumentList $argumentos -PassThru
    }

    $proc.Id | Out-File $pidFile -Encoding ascii -Force

    Write-Host "Demonio iniciado en segundo plano para: $directorio" -ForegroundColor Green
    exit 0
}

$PID | Out-File $pidFile

Get-ChildItem -Path $directorio -File | ForEach-Object {
    ProcesarArchivo $_.FullName
}

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $directorio
$watcher.Filter = '*.*'
$watcher.IncludeSubdirectories = $false
$watcher.EnableRaisingEvents = $true

$action = {
    ProcesarArchivo $Event.SourceEventArgs.FullPath
}

Register-ObjectEvent -InputObject $watcher -EventName Created -SourceIdentifier 'OnNuevoArchivo' -Action $action | Out-Null


while ($true) { Start-Sleep -Seconds 5 }

