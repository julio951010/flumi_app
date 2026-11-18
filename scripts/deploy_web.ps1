# Despliegue de la version web de Flumi en Cloudflare Pages.
#
# Uso:
#   .\scripts\deploy_web.ps1              # compila y publica en produccion (rama master)
#   .\scripts\deploy_web.ps1 -SkipBuild   # publica lo que ya hay en build\web
#   .\scripts\deploy_web.ps1 -Preview     # publica una URL de prueba (no toca produccion)
#
# Requisitos: flutter en el PATH y Node/npx (wrangler se descarga solo la
# primera vez). La primera vez pedira login de Cloudflare en el navegador.

param(
  [switch]$SkipBuild,
  [switch]$Preview,
  [string]$Proyecto = 'flumi'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

foreach ($cmd in @('flutter', 'npx')) {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
    throw "No encuentro '$cmd' en el PATH."
  }
}

$version = ((Get-Content pubspec.yaml | Select-String '^version:').Line -split ':\s*')[1].Trim()
Write-Host "Flumi web - version $version" -ForegroundColor Cyan

$dirty = @(git status --porcelain 2>$null)
if ($dirty.Count -gt 0) {
  Write-Host "AVISO: hay cambios sin commitear. Lo publicado no quedara identificado en git:" -ForegroundColor Yellow
  $dirty | ForEach-Object { Write-Host "  $_" }
}

if (-not $SkipBuild) {
  Write-Host "Compilando web (release)..." -ForegroundColor Cyan
  flutter build web --release
  if ($LASTEXITCODE -ne 0) { throw "flutter build web fallo (codigo $LASTEXITCODE)." }
}

$dist = Join-Path $root 'build\web'
if (-not (Test-Path (Join-Path $dist 'index.html'))) {
  throw "No existe $dist\index.html. Ejecuta sin -SkipBuild."
}
if (-not (Test-Path (Join-Path $dist 'sqlite3.wasm'))) {
  throw "Falta sqlite3.wasm en $dist. La base de datos local no funcionaria en el navegador."
}

$wranglerArgs = @('--yes', 'wrangler', 'pages', 'deploy', $dist, '--project-name', $Proyecto, '--commit-dirty=true')
if (-not $Preview) {
  $wranglerArgs += @('--branch', 'master')
  Write-Host "Publicando en PRODUCCION (rama master)..." -ForegroundColor Cyan
} else {
  Write-Host "Publicando una PREVIEW (no afecta produccion)..." -ForegroundColor Cyan
}

# wrangler escribe avisos por stderr y con $ErrorActionPreference='Stop'
# PowerShell los trataria como un fallo del script. Se aisla la llamada y se
# decide por el codigo de salida real del proceso.
$env:NO_COLOR = '1'
$eapPrevio = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$salida = & npx @wranglerArgs 2>&1
$codigo = $LASTEXITCODE
$ErrorActionPreference = $eapPrevio
$salida | ForEach-Object { Write-Host $_ }
if ($codigo -ne 0) { throw "wrangler pages deploy fallo (codigo $codigo)." }

if (-not $Preview) {
  $url = "https://$Proyecto.pages.dev"
  Write-Host "Comprobando $url ..." -ForegroundColor Cyan
  try {
    $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 30
    $ok = $r.StatusCode -eq 200 -and $r.Content -match 'flutter_bootstrap\.js'
    if ($ok) {
      Write-Host "OK: $url responde 200 y sirve la app." -ForegroundColor Green
    } else {
      Write-Host "ATENCION: $url respondio $($r.StatusCode) pero el HTML no parece el de Flutter." -ForegroundColor Yellow
    }
  } catch {
    Write-Host "ATENCION: no pude comprobar $url ($($_.Exception.Message))." -ForegroundColor Yellow
    Write-Host "Puede ser el proxy/DNS local; comprueba desde el movil." -ForegroundColor Yellow
  }
  Write-Host ""
  Write-Host "Listo: $url" -ForegroundColor Green
  Write-Host "Recuerda: si cambias de subdominio, los usuarios web tendran que iniciar sesion de nuevo." -ForegroundColor DarkGray
}
