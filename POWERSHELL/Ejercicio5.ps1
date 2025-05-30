#------------------------------------------------------------
# APL1. Ejercicio5
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
Busca frutas por ID o nombre utilizando la API pública fruityvice.

.DESCRIPTION
Este script permite buscar información sobre frutas específicas utilizando su ID o nombre.
Utiliza una caché local para evitar consultar dos veces por la misma fruta y muestra
los resultados en un formato plano.

.PARAMETER id
ID o IDs de las frutas a buscar. Puede pasarse uno o varios.

.PARAMETER name
Nombre o nombres de las frutas a buscar. Puede pasarse uno o varios.

.PARAMETER help
Muestra esta ayuda.

.EXAMPLE
.\Ejercicio5.ps1 -id 2

Busca la fruta con ID 2.

.EXAMPLE
.\Ejercicio5.ps1 -name banana -name apple

Busca las frutas banana y apple por nombre.

.EXAMPLE
.\Ejercicio5.ps1 -id 2 -name banana

Realiza búsqueda combinada por ID y nombre.

.NOTES
Utiliza la API: https://fruityvice.com/api/fruit/
Crea una caché en el directorio $env:LOCALAPPDATA\frutas o $HOME/frutas.
#>

param (
    [Parameter(HelpMessage="Id/s de las frutas a buscar")] 
    [array][Alias("i")]$id,

    [Parameter(HelpMessage="Nombre/s de las frutas a buscar")] 
    [array][Alias("n")]$name,

    [switch]$help
)

if ($help) {
    Write-Host ""
    Write-Host "Uso: .\Ejercicio5.ps1 -id <id> -name <nombre>" -ForegroundColor Green
    Write-Host "-id: Id/s de las frutas a buscar." -ForegroundColor Green
    Write-Host "-name: Nombre/s de las frutas a buscar." -ForegroundColor Green
    Write-Host "-help: Muestra esta ayuda." -ForegroundColor Green
    exit
}
Function PedirAAPI {
    param (
        [Parameter(Mandatory=$true)]
        [string]$identificador
    )
    $url = "https://fruityvice.com/api/fruit/$identificador"
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get
        if ($response) {
            ImprimirPlano -obj $response
            return $response
        }
    } catch {
        Write-Warning "Error al acceder a la API para '$identificador': $_"
    }
    return $null
}
Function YaEstaEnCache {
    param($campo, $valor)
    return $nuevaCache | Where-Object { $_.$campo -eq $valor }
}
function ProcesarObject {
    param(
        [object]$currentObj
    )

    foreach ($prop in $currentObj.PSObject.Properties) {
        $value = $prop.Value

        if ($value -is [System.Management.Automation.PSCustomObject]) {
            ProcesarObject -currentObj $value
        }
        elseif ($value -is [System.Collections.IEnumerable] -and $value -isnot [string]) {
            foreach ($item in $value) {
                if ($item -is [System.Management.Automation.PSCustomObject]) {
                    ProcesarObject -currentObj $item
                }
                else {
                    Write-Host "$($prop.Name): $item"
                }
            }
        }
        else {
            Write-Host "$($prop.Name): $value"
        }
    }
}
function ImprimirPlano {
    param (
        [Parameter(Mandatory = $true)]
        [object]$obj
    )
    if ($null -eq $obj) {
        Write-Warning "El objeto proporcionado es nulo."
        return
    }
    ProcesarObject -currentObj $obj
}

# Determinar carpeta de usuario compatible con Windows y Linux
$baseCache = if ($IsWindows) { $env:LOCALAPPDATA } else { $env:HOME }

if (-not $baseCache) {
    $baseCache = "."
}

$cacheDir = Join-Path $baseCache "frutas"
if (-not (Test-Path $cacheDir)) {
    New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
}
$cacheFile = Join-Path $cacheDir "cache.txt"
if (-not (Test-Path $cacheFile)) {
    New-Item -ItemType File -Path $cacheFile -Force | Out-Null
}

# Leer la caché una sola vez
$cache = @()
try {
    $rawCache = Get-Content $cacheFile -Raw
    if ($rawCache -ne "") {
        $cache = $rawCache | ConvertFrom-Json
    }
} catch {
    Write-Warning "No se pudo leer la caché. Se usará una vacía."
}

$nuevaCache = @()
if ($cache) {
    $nuevaCache += $cache
}


foreach ($nombre in $name) {
    $encontrado = YaEstaEnCache "name" $nombre
    if ($encontrado) {
        ImprimirPlano -obj $encontrado
    } else {
        $fruta = PedirAAPI -identificador $nombre
        if ($fruta) { $nuevaCache += $fruta }
    }
}


foreach ($ide in $id) {
    $encontrado = YaEstaEnCache "id" $ide
    if ($encontrado) {
        ImprimirPlano -obj $encontrado
    } else {
        $fruta = PedirAAPI -identificador $ide
        if ($fruta) { $nuevaCache += $fruta }
    }
}

# Guardar nueva caché (sin duplicados por ID)
$nuevaCache | Sort-Object id -Unique | ConvertTo-Json -Depth 5 | Set-Content -Path $cacheFile -Force