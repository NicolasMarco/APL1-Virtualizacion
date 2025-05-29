#------------------------------------------------------------
# APL1. Ejercicio3
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
Cuenta la cantidad de veces que aparecen determinadas palabras dentro de archivos de un directorio con extensiones específicas.

.DESCRIPTION
Este script permite recorrer recursivamente un directorio, buscar archivos con extensiones específicas (por ejemplo `.txt`, `.pdf`, `.docx`) y contar cuántas veces aparecen determinadas palabras en ellos. 
También muestra mensajes de estado sobre los archivos encontrados y procesados.

.PARAMETER directorio
Ruta del directorio donde se buscarán los archivos a analizar. Este parámetro es obligatorio.

.PARAMETER archivo
Lista de extensiones de archivo (sin el punto inicial) a buscar dentro del directorio. Este parámetro es obligatorio.

.PARAMETER palabras
Lista de palabras a contar dentro de los archivos encontrados. Este parámetro es obligatorio.

.PARAMETER help
Muestra la ayuda del script con información sobre su uso.

.EXAMPLE
.\Ejercicio.ps1 -directorio "C:\Documentos" -archivo "txt","pdf" -palabras "PowerShell","automatización"
Busca archivos con extensión .txt y .pdf dentro de "C:\Documentos" y cuenta cuántas veces aparecen las palabras "PowerShell" y "automatización".

.EXAMPLE
.\Ejercicio.ps1 -h
Muestra la ayuda del script.

.NOTES
- Para que el script pueda procesar archivos `.pdf`, es necesario tener instalado `pdftotext.exe` y que esté disponible en el PATH del sistema.
- Para archivos `.docx`, el script utiliza la aplicación de Word (COMObject), por lo tanto requiere que Microsoft Word esté instalado.
#>

param (
    [Parameter(HelpMessage="Ruta del directorio a analizar. ")]
    [ValidateScript({
        if (-not (Test-Path -Path $_ -PathType Container)) {
            Write-Host "El directorio especificado no existe: $_" -ForegroundColor Red
            exit
        }
        $true
    })]
    [string][Alias("d")]$directorio,
    
    [Parameter(HelpMessage="Lista de extensiones de archivos a buscar.")][ValidateNotNullOrEmpty()]
    [string[]][Alias("a")]$archivo,
    
    [Parameter(HelpMessage="Lista de palabras a contabilizar.")][ValidateNotNullOrEmpty()]
    [string[]][Alias("p")]$palabras,
    
    [Parameter(HelpMessage="Muestra esta ayuda.")]
    [switch][Alias("h")]$help
    )
    function ObtenerExtenciones {
        param (
            [Parameter(Mandatory=$true)]
            [string[]]$archivo
        )
    
        $lista = New-Object System.Collections.ArrayList
        $archivo | ForEach-Object { [void]$lista.Add($_) }
    
        return $lista
    }
    function ObtenerPalabras {
        param (
            [Parameter(Mandatory=$true)]
            [string[]]$palabras
        )
    
        $lista = New-Object System.Collections.ArrayList
        $palabras | ForEach-Object { [void]$lista.Add($_) }
    
        return $lista
    }
if($help){
    Write-Host "Uso: .\Ejercicio.ps1 -directorio <ruta> [-archivo <archivo salida>] [-palabras <palabras>] [-help]" -ForegroundColor Green
    Write-Host "-directorio: Ruta del directorio a analizar." -ForegroundColor Green
    Write-Host "-archivo: Lista de extenciones." -ForegroundColor Green
    Write-Host "-palabras: Lista de palabras a contabilizar." -ForegroundColor Green
    Write-Host "-help: Muestra esta ayuda." -ForegroundColor Green
    exit
}

if (-not $directorio) {
    Write-Host "Error: El parametro -directorio es obligatorio." -ForegroundColor Red
    exit
}

if (-not $archivo) {
    Write-Host "Error: El parametro -archivo es obligatorio." -ForegroundColor Red
    exit
}

if (-not $palabras) {
    Write-Host "Error: El parametro -palabras es obligatorio." -ForegroundColor Red
    exit
}



$listaPalabras = ObtenerPalabras -palabras $palabras
$listaExtenciones = ObtenerExtenciones -archivo $archivo

$contadorPalabras = @()
foreach ($palabra in $listaPalabras) {
    $contadorPalabras += [PSCustomObject]@{
        Palabra = $palabra
        Conteo  = 0
    }
}        

$listaExtenciones.ForEach({
    $extencion = $_
    if ($extencion -notlike ".*") {
        $extencion = ".$extencion"
    }
    $archivos = Get-ChildItem -Path $directorio -Filter "*$extencion" -File -Recurse
    
    if ($archivos.Count -eq 0) {
        Write-Host "No se encontraron archivos con la extensión .$extencion en el directorio $directorio." -ForegroundColor Yellow
    }
    else {
        Write-Host "Se encontraron $($archivos.Count) archivos con la extensión .$extencion en el directorio $directorio." -ForegroundColor Green
    }
    foreach ($arch in $archivos) {
        Write-Host "Procesando archivo: $($arch.FullName)" -ForegroundColor Cyan
        try {
            if ($arch.Extension -ieq ".pdf") {
                # Verifica si pdftotext.exe está en el PATH
                if (-not (Get-Command pdftotext.exe -ErrorAction SilentlyContinue)) { # https://github.com/oschwartz10612/poppler-windows/releases instalar libreria
                    Write-Host "pdftotext.exe no se encuentra en el PATH. Asegúrate de que esté instalado y en el PATH." -ForegroundColor Red
                    exit
                }
                $tempTxt = "$env:TEMP\$($arch.BaseName)_temp.txt"
                & pdftotext.exe -layout $arch.FullName $tempTxt
                $contenido = Get-Content $tempTxt -ErrorAction Stop
            } elseif ($arch.Extension -ieq ".docx") {
                # Inicializa la aplicación de Word para archivos .docx
                $wordApp = New-Object -ComObject Word.Application
                $wordApp.Visible = $false  # No mostrar la ventana de Word
                $doc = $wordApp.Documents.Open($arch.FullName)
                $contenido = $doc.Content.Text
                
                $doc.Close()
            } else {
                $contenido = Get-Content $arch.FullName -ErrorAction Stop
            }
            foreach ($linea in $contenido) {
                foreach ($palabra in $listaPalabras) {
                    $regex = [regex]::Escape($palabra)  
                    $regexMatches = [regex]::Matches($linea, "\b$regex\b", [System.Text.RegularExpressions.RegexOptions]::None)
                    if ($regexMatches.Count -gt 0) {
                        $contadorPalabras | Where-Object { $_.Palabra -ceq $palabra } | ForEach-Object {
                            $_.Conteo += $regexMatches.Count
                        }
                    }
                }
            }
        } catch {
            Write-Host "Error al procesar el archivo: $_" -ForegroundColor Red
        }
    }
    
})

$contadorPalabras | Sort-Object -Property Conteo -Descending | ForEach-Object {
    Write-Host "$($_.Palabra): $($_.Conteo)"
}