#------------------------------------------------------------
# APL1. Ejercicio2
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
    Realiza operaciones sobre una matriz numérica cargada desde un archivo.

.DESCRIPTION
    Este script permite procesar una matriz numérica desde un archivo de texto plano.
    Las operaciones disponibles son:
    - Transponer la matriz.
    - Multiplicar la matriz por un escalar.
    
    El archivo debe estar separado por un delimitador configurable, y puede contener números enteros o decimales (usando ',' o '.').
    El resultado se guarda como un nuevo archivo en la misma carpeta del archivo original.

.PARAMETER matriz
    Ruta del archivo que contiene la matriz a procesar.

.PARAMETER separador
    Caracter que separa los elementos de cada fila de la matriz. No puede ser un número ni los caracteres "-" o ",".

.PARAMETER trasponer
    Indica si se debe transponer la matriz. No se puede usar junto con -producto.

.PARAMETER producto
    Número por el cual se multiplicará cada elemento de la matriz. No se puede usar junto con -trasponer.

.PARAMETER help
    Muestra la ayuda detallada del script.

.EXAMPLE
    .\Ejercicio2.ps1 -matriz .\matriz.csv -separador ";" -trasponer

    Transpone la matriz ubicada en 'matriz.csv' usando ';' como separador y guarda el resultado en un nuevo archivo.

.EXAMPLE
    .\Ejercicio2.ps1 -matriz .\matriz.csv -separador "," -producto 3.5

    Multiplica por 3.5 todos los valores de la matriz ubicada en 'matriz.csv' y guarda el resultado.
#>
param (
   [Parameter(Mandatory=$true, HelpMessage="Ruta del archivo de la matriz.")]
[Alias("m")]
[ValidateScript({
    if (-not (Test-Path $_ -PathType Leaf)) {
        throw "El archivo especificado no existe o no es un archivo."
    }
    $contenido = Get-Content -Path $_
    if ($contenido.Count -eq 0) {
        throw "El archivo está vacío: $_"
    }
    return $true
})]
[string]$matriz,

    [Parameter(Mandatory=$true, HelpMessage="Separador del archivo.")]
    [Alias("s")]
    [ValidateLength(1,1)]
    [ValidateScript({ 
        if ($_ -match '[0-9\-]') {
            throw "El separador no puede ser un número ni un guion."
        }
        return $true
    })]
    [string]$separador,

    [Parameter(HelpMessage="Transponer matriz.")]
    [Alias("t")]
    [switch]$trasponer,

    [Parameter(HelpMessage="Multiplicar por escalar.")]
    [Alias("p")]
    [double]$producto,

    [Parameter(HelpMessage="Muestra esta ayuda.")]
    [Alias("h")]
    [switch]$help
)



function ObtenerMatriz {
    param (
        [Parameter(Mandatory=$true)]
        [string]$origen,

        [Parameter(Mandatory=$true)]
        [string]$separador
    )

    $matrizArray = @()
    $lineas = Get-Content -Path $origen

    foreach ($linea in $lineas) {
        $elementos = $linea -split [regex]::Escape($separador)
        $fila = @()

        foreach ($elemento in $elementos) {
            $valor = $elemento.Trim()

           
            if ($valor -match '^-?\d+([.,]\d+)?$') {
                
                try {
                    $fila += [double]::Parse($valor, [System.Globalization.CultureInfo]::InvariantCulture)
                } catch {
                    Write-Host "Error al convertir '$valor' a número." -ForegroundColor Red
                }
            } else {
                Write-Host "Error: Valor no numérico '$valor'" -ForegroundColor Red
                exit
            }
        }

        $matrizArray += ,$fila
    }

    return $matrizArray
}



function TrasponerMatriz {
    param (
        [Parameter(Mandatory=$true)]
        [array]$matriz
    )

    $matrizTraspuesta = @()

    $filas = $matriz.Count
    $columnas = $matriz[0].Count

    for ($i = 0; $i -lt $columnas; $i++) {
        $nuevaFila = @()
        for ($j = 0; $j -lt $filas; $j++) {
            $nuevaFila += $matriz[$j][$i]
        }
        $matrizTraspuesta += ,$nuevaFila
    }

    return $matrizTraspuesta
}
function ProductoMatriz {
    param (
        [Parameter(Mandatory=$true)]
        [array]$matriz,

        [Parameter(Mandatory=$true)]
        [double]$producto
    )
    $resultado = @()
    foreach ($line in $matriz) {
        
        $filaResultado = @()
        foreach ($element in $line) {
            $resultadoDouble = [double]0.0
            $resultadoDouble += [double]$element * $producto
            $filaResultado += $resultadoDouble
        }
        $resultado += ,$filaResultado 
    }
    return $resultado
}
function GuardarMatrizEnArchivo {
    param (
        [Parameter(Mandatory=$true)]
        [array]$matriz,

        [Parameter(Mandatory=$true)]
        [string]$archivoEntrada,

        [Parameter()]
        [string]$separador
    )

    # Obtener nombre y carpeta del archivo original
    $nombreEntrada = [System.IO.Path]::GetFileName($archivoEntrada)
    $carpeta = [System.IO.Path]::GetDirectoryName((Resolve-Path $archivoEntrada))
    $nombreSalida = "salida.$nombreEntrada"
    $rutaSalida = Join-Path -Path $carpeta -ChildPath $nombreSalida

    # Preparar contenido como texto
    $lineas = @()
    foreach ($fila in $matriz) {
        $lineas += ($fila -join $separador)
    }

    # Escribir en archivo
    Set-Content -Path $rutaSalida -Value $lineas -Encoding UTF8
    Write-Host "Matriz escrita en: $rutaSalida" -ForegroundColor Green
}

if ($help) {
    Write-Host "Uso: .\Ejercicio2.ps1 -matriz <ruta> [-separador <archivo salida>] ([-trasponer] ó [-producto]) [-help]" -ForegroundColor Green
    Write-Host "-matriz: Ruta del directorio donde se buscara la matriz." -ForegroundColor Green
    Write-Host "-separador: Caracter por el cual se separara cada elemento de la matriz ." -ForegroundColor Green
    Write-Host "-trasponer: Muestra el resultado en pantalla." -ForegroundColor Green
    Write-Host "-producto: Muestra el resultado en pantalla, ingresar numero para multiplicar." -ForegroundColor Green
    Write-Host "-help: Muestra esta ayuda." -ForegroundColor Green
    exit
}

if (-not $matriz) {
    Write-Host "Error: El parametro -matriz es obligatorio." -ForegroundColor Red
    exit
}

if (-not $separador) {
    Write-Host "Error: El parametro -separador es obligatorio." -ForegroundColor Red
    exit
}

if($trasponer -and $producto){
    Write-Host "Debe seleccionar trasponer o producto, no se pueden los dos a la vez" -ForegroundColor Red
    exit
}
if(-not( $trasponer -or $producto)){
    Write-Host "Debe seleccionar trasponer o producto." -ForegroundColor Red
    exit
}
# Validación de la matriz y el separador juntos (antes de procesar)
$contenido = Get-Content -Path $matriz

$numeroColumnas = -1
foreach ($linea in $contenido) {
    $elementos = $linea -split [regex]::Escape($separador)
    if ($numeroColumnas -eq -1) {
        $numeroColumnas = $elementos.Count
        if ($numeroColumnas -eq 0) {
            Write-Host "No se detectaron columnas válidas en la primera línea." -ForegroundColor Red
            exit
        }
    } elseif ($elementos.Count -ne $numeroColumnas) {
        Write-Host "Inconsistencia en el número de columnas en alguna línea." -ForegroundColor Red
        exit
    }
    foreach ($elemento in $elementos) {
        if (-not ($elemento -match '^-?\d+([.,]\d+)?$')) {
            Write-Host "Elemento no numérico encontrado: '$elemento'" -ForegroundColor Red
            exit
        }
    }
}


$matrix = ObtenerMatriz -origen $matriz -separador $separador

if ($trasponer) {
    $resultado = TrasponerMatriz -matriz $matrix
} elseif ($producto) {
    $resultado = ProductoMatriz -matriz $matrix -producto $producto
}
if (-not $matriz) {
    Write-Host "Error: El parametro -matriz es obligatorio." -ForegroundColor Red
    exit
}

if (-not $separador) {
    Write-Host "Error: El parametro -separador es obligatorio." -ForegroundColor Red
    exit
}

GuardarMatrizEnArchivo -matriz $resultado -archivoEntrada $matriz -separador $separador