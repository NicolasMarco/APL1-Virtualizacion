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
    
        [Parameter(Mandatory=$true, ParameterSetName='Monitor')]
        [Parameter(Mandatory=$true, ParameterSetName='Kill')]
        [ValidateScript({
            if (-not (Test-Path -Path $_ -PathType Container)) {
                Write-Host "El directorio especificado no existe: $_" -ForegroundColor Red
                exit 1
            }
            $true
        })]
        [string][Alias("d")]$directorio,

        [Parameter(Mandatory=$true, ParameterSetName='Monitor')]
        [ValidateScript({
            if (-not (Test-Path -Path $_ -PathType Container)) {
                Write-Host "Error: salida no existe: $_" -ForegroundColor Red
                exit 1
            }
            $true
        })]
        [string][Alias("s")]$salida,

        [Parameter(Mandatory=$true, ParameterSetName='Monitor')]
        [int][Alias("c")]$cantidad,

        [Parameter(ParameterSetName='Monitor')]
        [switch]$bg,

    
        [Parameter(Mandatory=$true, ParameterSetName='Kill')]
        [switch][Alias("k")]$kill,

        
        [Parameter(ParameterSetName='Monitor')]
        [Parameter(ParameterSetName='Kill')]
        [Parameter(Mandatory=$true, ParameterSetName='help  ')]
        [switch][Alias("h")]$help
    )

    $esWindows = $env:OS -like "*Windows*"

    function CrearBackup {
    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    $base = Split-Path $directorio -Leaf
    $nombreBase = "$base`_$ts"
    $zip = "$nombreBase.zip"
    $dest = Join-Path $salida $zip

    $contadorNombre = 1
    while (Test-Path $dest) {
        $zip = "$nombreBase`_$contadorNombre.zip"
        $dest = Join-Path $salida $zip
        $contadorNombre++
    }

    if ($esWindows) {
        try {
            Compress-Archive -Path (Join-Path $directorio '*') -DestinationPath $dest -Force
        }
        catch {
            Write-Warning "[ERROR] Falló la creación del backup: $($_.Exception.Message)"
        }
    } else {
        try {
            Push-Location $directorio
            & zip -r "$dest" * | Out-Null
            Pop-Location
        } catch {
            Write-Warning "[ERROR] Falló la creación del backup: $($_.Exception.Message)"
        }
    }   
    $global:contador = 0
}
    function EsperarArchivoDisponible {
    param($path)
    $maxIntentos = 10
    for ($i = 0; $i -lt $maxIntentos; $i++) {
        try {
            $stream = [System.IO.File]::Open($path, 'Open', 'Read', 'ReadWrite')
            $stream.Close()
            return $true
        } catch {
            Start-Sleep -Milliseconds 30
        }
    }
    return $false
}
        
        function ProcesarArchivo($file) {
                if ($file -like '*.lock') { return }

                $lockFile = "$file.lock"
                if (Test-Path $lockFile) { return }

                try {
                    New-Item -ItemType File -Path $lockFile -Force -ErrorAction Stop | Out-Null
                } catch {
                    Write-Warning "No se pudo crear lock para: $file"
                    return
                }

                $backupNecesario = $false

                try {
                    if (-not (EsperarArchivoDisponible $file)) {
                        return
                    }

                    Start-Sleep -Milliseconds 30

                    if (-not (Test-Path $file -PathType Leaf)) { return }

                    $ext = [IO.Path]::GetExtension($file).TrimStart('.')
                    if ([string]::IsNullOrEmpty($ext)) { $ext = 'SinExtension' }

                    $dest = Join-Path $directorio $ext.ToUpper()
                    if (-not (Test-Path $dest)) {
                        New-Item -ItemType Directory -Path $dest | Out-Null
                    }

                    Move-Item -Path $file -Destination $dest -Force
                    $global:contador++

                    if ($global:contador -ge $cantidad) {
                        $backupNecesario = $true
                    }
                }
                catch {
                    Write-Warning "Error al mover archivo: $_"
                }
                finally {
                    if (Test-Path $lockFile) {
                        Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
                    }
                }

                # Ejecutar fuera del bloque try-finally para evitar que afecte a la limpieza del lock
                if ($backupNecesario) {
                    CrearBackup
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
    
    
if($salida){
    $salida = (Resolve-Path -Path $salida).Path
}

$directorio = (Resolve-Path -Path $directorio).Path

$pidBase = Join-Path $HOME "demonioOrdenarArchivos"
if (-not (Test-Path $pidBase)) {
    New-Item -ItemType Directory -Path $pidBase -Force | Out-Null
}

# Generar archivo PID único por hash del path absoluto
$hash = [System.BitConverter]::ToString(
    (New-Object System.Security.Cryptography.SHA256Managed).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($directorio))
) -replace '-', ''
$pidFile = Join-Path $pidBase "daemon_$hash.pid"

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

if (-not $bg) {
    #$pwsh = (Get-Command pwsh).Source
    $pwsh = (Get-Process -Id $PID).Path

    $argumentos = @(
        "-File", "`"$PSCommandPath`"",
        "-directorio", "`"$directorio`"",
        "-salida", "`"$salida`"",
        "-cantidad", "$cantidad",
        "-bg"
    )

    if ($esWindows) {
        Start-Process -FilePath $pwsh `
            -ArgumentList $argumentos `
            -WindowStyle Hidden `
            -PassThru | Out-Null
    }
    else {
        Start-Process -FilePath $pwsh `
            -ArgumentList $argumentos `
            -PassThru | Out-Null
    }

    Write-Host "Demonio iniciado en segundo plano para: $directorio" -ForegroundColor Green
    exit 0
}

#if (-not $bg) {
#    $argumentos = "-File `"$PSCommandPath`" -directorio `"$directorio`" -salida `"$salida`" -cantidad $cantidad -bg"
    
#    $comando = "nohup pwsh $argumentos > /dev/null 2>&1 & disown"
    
#    bash -c $comando

#    Write-Host "Demonio iniciado en segundo plano para: $directorio" -ForegroundColor Green
#    exit 0
#}

$PID | Out-File $pidFile

Get-ChildItem -Path $directorio -File | ForEach-Object {
    ProcesarArchivo $_.FullName
}

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $directorio
$watcher.Filter = '*.*'
$watcher.IncludeSubdirectories = $false
$watcher.EnableRaisingEvents = $true
Write-Host "Watcher initialized for: $($watcher.Path)"


$action = {
    try {
        Start-Sleep -Milliseconds 30  # permite que se termine de escribir el archivo
        ProcesarArchivo $Event.SourceEventArgs.FullPath 
    }
    catch {
        Write-Warning "Error en acción del watcher: $_"
    }
}
Unregister-Event -SourceIdentifier 'OnNuevoArchivo' -ErrorAction SilentlyContinue

Register-ObjectEvent -InputObject $watcher -EventName Created -SourceIdentifier 'OnNuevoArchivo' -Action $action | Out-Null
Register-ObjectEvent -InputObject $watcher -EventName Changed -SourceIdentifier 'OnArchivoCambiado' -Action $action | Out-Null
Register-ObjectEvent -InputObject $watcher -EventName Renamed -SourceIdentifier 'OnArchivoRenombrado' -Action $action | Out-Null


while ($true) {
    Get-ChildItem -Path $directorio -File | ForEach-Object {
        ProcesarArchivo $_.FullName
    }
    Start-Sleep -Seconds 5
}